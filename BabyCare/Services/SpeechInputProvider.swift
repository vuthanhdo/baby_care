import AVFoundation
import Speech

@MainActor
protocol SpeechInputProvider: AnyObject {
    func start(onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor (String?) -> Void) async
    func stop()
    func cancel()
}

/// Audio is streamed to Apple's recognizer; no recording file is retained.
@MainActor
final class AppleSpeechInputProvider: SpeechInputProvider {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var token = UUID()
    private var tapped = false
    private var audioActive = false
    private var completion: (@MainActor (String?) -> Void)?
    private var timeout: Task<Void, Never>?
    private var interruption: NSObjectProtocol?

    func start(onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor (String?) -> Void) async {
        cancel()
        let generation = token
        completion = onEnd
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard status == .authorized else {
            finish(L10n.text("Chưa được phép nhận dạng giọng nói. Hãy kiểm tra quyền trong Cài đặt của iPhone."))
            return
        }
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard generation == token else { return }
        guard allowed else {
            finish(L10n.text("Chưa được phép dùng micrô. Hãy bật quyền Micrô trong Cài đặt của iPhone."))
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN")), recognizer.isAvailable else {
            finish(L10n.text("Nhận dạng tiếng Việt hiện không khả dụng. Kiểm tra kết nối mạng hoặc thử lại sau."))
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            audioActive = true
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                finish(L10n.text("Không tìm thấy micrô khả dụng. Hãy kiểm tra thiết bị âm thanh rồi thử lại."))
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.contextualStrings = ["Bé uống sữa", "nhiệt độ", "thay tã", "bú mẹ", "mililít"]
            self.request = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapped = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let failed = error != nil
                let uncertain = result?.isFinal == true && (result?.bestTranscription.segments.contains { $0.confidence > 0 && $0.confidence < 0.5 } ?? false)
                Task { @MainActor [weak self] in
                    guard let self, self.token == generation else { return }
                    if let text { onText(text) }
                    if failed { self.finish(L10n.text("Nhận dạng đã dừng. Nội dung đã nghe vẫn được giữ; bạn có thể thử lại hoặc sửa bằng bàn phím.")) }
                    else if uncertain { self.finish(L10n.text("Có từ chưa nghe rõ. Hãy kiểm tra văn bản hoặc nói lại; chưa tự lưu hoạt động nào.")) }
                    else if final { self.finish(nil) }
                }
            }
            interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.token == generation else { return }
                    self?.finish(L10n.text("Micrô bị gián đoạn. Nội dung đã nghe vẫn được giữ."))
                }
            }
            engine.prepare()
            try engine.start()
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(55))
                guard !Task.isCancelled, self?.token == generation else { return }
                self?.stop()
            }
        } catch {
            finish(L10n.text("Không thể bắt đầu micrô. Hãy thử lại hoặc nhập bằng bàn phím."))
        }
    }

    func stop() {
        guard completion != nil else { return }
        // During permission prompts there is no audio session to finalize.
        guard request != nil else { finish(L10n.text("Đã hủy trước khi bắt đầu nhận dạng. Chưa lưu hoạt động nào.")); return }
        stopAudio()
        request?.endAudio()
        timeout?.cancel()
        let generation = token
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, self?.token == generation else { return }
            self?.finish(L10n.text("Chưa nhận được kết quả cuối. Hãy nói lại hoặc sửa văn bản rồi bấm Phân tích và lưu."))
        }
    }

    func cancel() {
        token = UUID()
        completion = nil
        timeout?.cancel()
        timeout = nil
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        interruption = nil
    }

    private func stopAudio() {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        if audioActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioActive = false
        }
    }

    private func finish(_ message: String?) {
        let handler = completion
        cancel()
        handler?(message)
    }
}
