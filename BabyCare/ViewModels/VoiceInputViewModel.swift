import Foundation
import Observation

@MainActor @Observable
final class VoiceInputViewModel {
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var isFinishing = false
    private(set) var message: String?
    private(set) var completedRecognition = 0
    private(set) var isSaving = false
    private(set) var savedActivities: [CareActivity] = []
    @ObservationIgnored private var pending: (text: String, babyID: UUID, entries: [CareActivity])?
    @ObservationIgnored private let provider: any SpeechInputProvider
    @ObservationIgnored private var generation = UUID()

    init(provider: (any SpeechInputProvider)? = nil) {
        self.provider = provider ?? AppleSpeechInputProvider()
    }

    func edit(_ text: String) {
        guard !isListening, !isSaving else { return }
        transcript = text
    }

    func start() async {
        guard !isListening, !isSaving else { return }
        generation = UUID()
        let token = generation
        var receivedText = false
        isListening = true
        isFinishing = false
        message = nil
        await provider.start(onText: { [weak self] text in
            guard let self, self.generation == token else { return }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            receivedText = true
            self.transcript = text
        }, onEnd: { [weak self] error in
            guard let self, self.generation == token else { return }
            self.isListening = false
            self.isFinishing = false
            self.message = error ?? (receivedText ? nil : L10n.text("Chưa nghe rõ nội dung. Hãy nói lại; chưa lưu hoạt động nào."))
            self.generation = UUID()
            if error == nil && receivedText { self.completedRecognition += 1 }
        })
    }

    /// The callback invokes the same action/data provider as manual activity entry.
    func parseAndSave(babyID: UUID, now: Date = Date(), calendar: Calendar = .current,
                      save: @MainActor ([CareActivity]) async -> Bool) async {
        guard !isListening, !isSaving else { return }
        message = nil
        do {
            if pending?.text != transcript || pending?.babyID != babyID {
                let entries = try VoiceActivityParser().parse(transcript, now: now, calendar: calendar)
                // Reuse manual validation in addition to the complete-statement parser.
                guard entries.allSatisfy({ ActivityFormViewModel(kind: $0.kind, activity: $0).valid }) else {
                    throw VoiceActivityParser.ParseError(message: L10n.text("Dữ liệu hoạt động chưa hợp lệ. Hãy kiểm tra số liệu và thời gian; chưa lưu hoạt động nào."))
                }
                pending = (transcript, babyID, entries)
            }
            guard let pending else { return }
            isSaving = true
            defer { isSaving = false }
            guard await save(pending.entries) else {
                message = L10n.text("Chưa lưu được dữ liệu. Hãy thử lại; nội dung và mã hoạt động được giữ để tránh tạo bản ghi trùng.")
                return
            }
            savedActivities = pending.entries
            transcript = ""
            self.pending = nil
        } catch {
            message = error.localizedDescription
        }
    }

    func stop() {
        guard isListening, !isFinishing else { return }
        isFinishing = true
        provider.stop()
    }

    func cancel() {
        generation = UUID()
        provider.cancel()
        isListening = false
        isFinishing = false
    }
}
