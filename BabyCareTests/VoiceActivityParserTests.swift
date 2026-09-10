import Foundation
import Testing
@testable import BabyCare

@MainActor
struct VoiceActivityParserTests {
    private var now: Date { Date(timeIntervalSince1970: 1_700_049_600) }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test func conversationalVariantsAndSpokenNumbers() throws {
        let cases: [(String, ActivityKind, Double?)] = [
            ("Mẹ vừa cho bé uống một trăm hai mươi ml sữa nhé", .milk, 120),
            ("Con em vừa uống sữa hết 150ml", .milk, 150),
            ("Bé bú được chín mươi ml", .milk, 90),
            ("Bé bú sữa một trăm linh năm cc", .milk, 105),
            ("Em bé bú mẹ được mười phút", .milk, 10),
            ("Ghi giúp mình bé uống nước ba mươi ml nha", .water, 30),
            ("Bé đo được ba mươi bảy phẩy năm độ", .temperature, 37.5),
            ("Đo nách được 37,2 độ", .temperature, 37.2),
            ("Bé uống thuốc paracetamol không phẩy năm ml", .medicine, 0.5),
            ("Bé ngủ nửa tiếng", .sleep, 30),
            ("Con mình ngủ được một giờ rưỡi", .sleep, 90),
            ("Bé ngủ hai giờ mười lăm phút", .sleep, 135),
            ("Mình đã cho bé tắm xong", .bath, nil),
            ("Thay bỉm cho bé xong", .diaper, nil)
        ]
        for (text, kind, number) in cases {
            let result = try VoiceActivityParser().parse(text, now: now, calendar: calendar)[0]
            #expect(result.kind == kind, "\(text)")
            #expect(result.numericValue == number, "\(text)")
            #expect(result.date == now)
            #expect(result.note == text)
        }
    }

    @Test func conversationalTimesAndConjunctions() throws {
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 16))!
        for text in ["Bé uống 120 ml sữa lúc bảy giờ rưỡi sáng", "Bé uống 120 ml sữa hồi 7h30 sáng", "Sáng nay bảy giờ rưỡi bé uống 120 ml sữa"] {
            let entry = try VoiceActivityParser().parse(text, now: reference, calendar: calendar)[0]
            #expect(calendar.component(.hour, from: entry.date) == 7)
            #expect(calendar.component(.minute, from: entry.date) == 30)
        }
        let earlier = try VoiceActivityParser().parse("Bé thay bỉm mười phút trước", now: reference, calendar: calendar)[0]
        #expect(earlier.date == reference.addingTimeInterval(-600))
        let batch = try VoiceActivityParser().parse("Bé uống sữa 120ml và bé thay tã. Bé tắm xong", now: reference, calendar: calendar)
        #expect(batch.count == 3)
    }

    @Test func flexibleGrammarStillRejectsAmbiguousOrIncompleteSpeech() {
        for text in ["Bé chưa bú được 120 ml", "Bé định uống sữa 120 ml", "Bé uống sữa một trăm hai ml", "Bé bú một hai ml", "Bé uống sữa 120", "Bé uống thuốc paracetamol", "Bé ngủ", "Bé uống sữa 120 ml và bé chưa thay tã", "Bé uống thuốc paracetamol hoặc ibuprofen 2 ml"] {
            #expect(throws: VoiceActivityParser.ParseError.self) { try VoiceActivityParser().parse(text) }
        }
    }

    @Test func recognizesSupportedActivitiesAndKeepsOriginalSpeech() throws {
        let cases: [(String, ActivityKind, String, String)] = [
            ("Bé uống 120 ml sữa", .milk, "120", "ml"),
            ("Bé uống nước 30 ml", .water, "30", "ml"),
            ("Bé bú mẹ 15 phút", .milk, "15", "phút"),
            ("Bé đo nhiệt độ 37,5 độ ở nách", .temperature, "37,5", "°C"),
            ("Bé uống thuốc paracetamol 2,5 ml", .medicine, "2,5", "ml"),
            ("Bé ngủ 1 giờ", .sleep, "60.0", "phút"),
            ("Bé tắm xong", .bath, "Đã ghi nhận", ""),
            ("Bé thay tã ướt", .diaper, "ướt", "")
        ]
        for (text, kind, value, unit) in cases {
            let result = try VoiceActivityParser().parse(text, now: now, calendar: calendar)
            #expect(result.count == 1)
            #expect(result[0].kind == kind)
            #expect(result[0].value == value)
            #expect(result[0].unit == unit)
            #expect(result[0].note == text)
            #expect(result[0].date == now)
        }
    }

    @Test func parsesExplicitAndRelativeTimeWithoutRollingFutureIntoYesterday() throws {
        let parser = VoiceActivityParser()
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 16))!
        let yesterday = try parser.parse("Bé uống 120 ml sữa lúc 7 giờ 30 sáng hôm qua", now: reference, calendar: calendar)[0]
        #expect(calendar.component(.day, from: yesterday.date) == 9)
        #expect(calendar.component(.hour, from: yesterday.date) == 7)
        #expect(calendar.component(.minute, from: yesterday.date) == 30)
        let noon = try parser.parse("Bé thay tã lúc 11 giờ trưa", now: reference, calendar: calendar)[0]
        #expect(calendar.component(.hour, from: noon.date) == 11)
        #expect(throws: VoiceActivityParser.ParseError.self) {
            try parser.parse("Bé thay tã lúc 7 giờ trưa", now: reference, calendar: calendar)
        }
        let earlier = try parser.parse("Bé thay tã cách đây 10 phút", now: reference, calendar: calendar)[0]
        #expect(earlier.date == reference.addingTimeInterval(-600))
        #expect(throws: VoiceActivityParser.ParseError.self) {
            try parser.parse("Bé uống 120 ml sữa lúc 7 giờ tối", now: reference, calendar: calendar)
        }
    }

    @Test func rejectsNegationAmbiguityMissingUnitsAndUnsupportedStatements() {
        for text in ["", "Bé chưa uống 120 ml sữa", "Bé sẽ uống 120 ml sữa", "Bé uống 120 sữa", "Bé uống khoảng 120 ml sữa", "Bé uống -120 ml sữa", "Bé uống 0 ml nước", "Bé uống 120 hoặc 150 ml sữa", "Bé uống thuốc 2 ml", "Bé uống thuốc paracetamol và ibuprofen 2 ml", "Bé uống 120 ml sữa hôm qua", "Bé uống 120 ml sữa lúc 25 giờ", "Bé uống 120 ml sữa và không tắm", "Hôm nay trời đẹp", "Bé uống 120 ml sữa rồi không nghe rõ"] {
            #expect(throws: VoiceActivityParser.ParseError.self) {
                try VoiceActivityParser().parse(text, now: now, calendar: calendar)
            }
        }
    }

    @Test func missingTimeUsesNowForEveryActivityAndMultipleActivitiesAreSeparate() throws {
        let entries = try VoiceActivityParser().parse("Bé ngủ 30 phút rồi bé uống 120 ml sữa", now: now, calendar: calendar)
        #expect(entries.count == 2)
        #expect(entries[0].date == now)
        #expect(entries[1].date == now)
        #expect(entries[0].detail == CareActivity.recordedSleepDetail)
        #expect(entries[0].id != entries[1].id)
    }

    @Test func invalidSentenceNeverCallsSaveAndRetainsTranscript() async {
        let model = VoiceInputViewModel()
        model.edit("Bé uống 120 ml sữa rồi không nghe rõ")
        var calls = 0
        await model.parseAndSave(babyID: UUID()) { _ in calls += 1; return true }
        #expect(calls == 0)
        #expect(model.message != nil)
        #expect(!model.transcript.isEmpty)
    }

    @Test func parsedSpeechPersistsThroughExistingActionAndDatabaseReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = CarePersistenceConfiguration(storeURL: folder.appending(path: "voice.store"))
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        let app = BabyCareViewModel(provider: provider)
        #expect(await app.send(.load))
        let baby = BabyProfile(name: "Voice Test", birthDate: Date().addingTimeInterval(-86400))
        #expect(await app.send(.commit(.createBaby(baby))))
        let voice = VoiceInputViewModel()
        voice.edit("Bé ngủ 30 phút rồi bé thay tã")
        await voice.parseAndSave(babyID: baby.id) { entries in
            await app.send(.commit(.saveActivities(babyID: baby.id, entries: entries)))
        }
        let reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.activities.count == 2)
        #expect(Set(reopened.selectedBaby?.activities.map(\.id) ?? []) == Set(voice.savedActivities.map(\.id)))
    }

    @Test func successfulSaveUsesBatchActionOnceAndRetryKeepsIdentifiers() async {
        let model = VoiceInputViewModel()
        let babyID = UUID()
        model.edit("Bé uống 120 ml sữa rồi bé thay tã")
        var batches: [[CareActivity]] = []
        await model.parseAndSave(babyID: babyID) { entries in batches.append(entries); return false }
        #expect(!model.transcript.isEmpty)
        #expect(model.savedActivities.isEmpty)
        await model.parseAndSave(babyID: babyID) { entries in batches.append(entries); return true }
        #expect(batches.count == 2)
        #expect(batches[0] == batches[1])
        #expect(model.savedActivities.count == 2)
        #expect(model.transcript.isEmpty)
        await model.parseAndSave(babyID: babyID) { _ in Issue.record("Saved an empty/consumed transcript twice"); return true }
    }
}
