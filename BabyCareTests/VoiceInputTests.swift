import Foundation
import Testing
@testable import BabyCare

@MainActor
private final class FakeSpeechProvider: SpeechInputProvider {
    var text: (@MainActor (String) -> Void)?
    var end: (@MainActor (String?) -> Void)?
    var starts = 0
    var stops = 0
    var cancels = 0
    func start(onText: @escaping @MainActor (String) -> Void, onEnd: @escaping @MainActor (String?) -> Void) async {
        starts += 1
        text = onText
        end = onEnd
    }
    func stop() { stops += 1 }
    func cancel() { cancels += 1 }
}

@MainActor
struct VoiceInputTests {
    @Test func partialResultsReplaceAndNewSessionsDoNotResavePreviousSpeech() async {
        let provider = FakeSpeechProvider()
        let model = VoiceInputViewModel(provider: provider)
        model.edit("Ghi chú cũ")
        await model.start()
        provider.text?("Bé uống")
        provider.text?("Bé uống 120 ml sữa")
        #expect(model.transcript == "Bé uống 120 ml sữa")
        provider.end?(nil)
        await model.start()
        provider.text?("Bé đã tắm")
        #expect(model.transcript == "Bé đã tắm")
    }

    @Test func stopAcceptsFinalResultAndPreventsDuplicateStart() async {
        let provider = FakeSpeechProvider()
        let model = VoiceInputViewModel(provider: provider)
        await model.start()
        await model.start()
        model.edit("Không được ghi đè khi đang nghe")
        #expect(model.transcript.isEmpty)
        #expect(provider.starts == 1)
        model.stop()
        model.stop()
        #expect(provider.stops == 1)
        #expect(model.isFinishing)
        provider.text?("37,5 độ")
        provider.end?(nil)
        #expect(model.transcript == "37,5 độ")
        #expect(!model.isListening && !model.isFinishing)
    }

    @Test func onlyFinalSuccessTriggersActionAndEmptyOrFailedSessionCannotSaveOldText() async {
        let provider = FakeSpeechProvider()
        let model = VoiceInputViewModel(provider: provider)
        model.edit("Bé uống 120 ml sữa")
        await model.start()
        provider.end?(nil)
        #expect(model.completedRecognition == 0)
        #expect(model.message != nil)
        await model.start()
        provider.text?("Bé thay tã")
        #expect(model.completedRecognition == 0)
        provider.end?("Mất mạng")
        #expect(model.completedRecognition == 0)
        await model.start()
        provider.text?("Bé tắm xong")
        let duplicateEnd = provider.end
        provider.end?(nil)
        duplicateEnd?(nil)
        #expect(model.completedRecognition == 1)
        #expect(model.transcript == "Bé tắm xong")
    }

    @Test func interruptionKeepsTextAndCancelIgnoresLateCallbacks() async {
        let provider = FakeSpeechProvider()
        let model = VoiceInputViewModel(provider: provider)
        await model.start()
        provider.text?("Đã thay tã")
        provider.end?("Mất kết nối")
        #expect(model.message == "Mất kết nối")
        #expect(model.transcript == "Đã thay tã")
        await model.start()
        let stale = provider.text
        model.cancel()
        stale?("Kết quả đến muộn")
        #expect(model.transcript == "Đã thay tã")
        #expect(!model.isListening)
        #expect(provider.cancels == 1)
    }
}
