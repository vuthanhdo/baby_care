import Foundation
import Testing
@testable import BabyCare

@MainActor
struct BabyCareTests {
    @Test func destructiveConfirmationAcceptsVietnameseToneVariants() {
        #expect(DestructiveConfirmation.matches("XÓA"))
        #expect(DestructiveConfirmation.matches("XOÁ"))
        #expect(DestructiveConfirmation.matches("  xoa\n"))
        #expect(!DestructiveConfirmation.matches("XÓA HẾT"))
        #expect(!DestructiveConfirmation.matches(""))
    }

    @Test func activityCreateEditDeleteAndPhotosSurviveDiskReopening() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(in: folder)
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        let baby = profile()
        _ = try await provider.apply(.createBaby(baby))
        var entry = CareActivity(kind: .temperature, value: "38,1", unit: "°C", detail: "Nách", attachments: [Data(repeating: 42, count: 200_000)])
        _ = try await provider.apply(.saveActivities(babyID: baby.id, entries: [entry]))
        var reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.activities == [entry])
        #expect(reopened.hasOnboarded)
        #expect(FileManager.default.fileExists(atPath: configuration.storeURL.path))

        entry.value = "37,7"
        entry.note = "Đã sửa"
        entry.attachments = [Data("ảnh thay thế".utf8)]
        _ = try await provider.apply(.saveActivities(babyID: baby.id, entries: [entry]))
        reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.activities == [entry])
        _ = try await provider.apply(.deleteActivity(babyID: baby.id, activityID: entry.id))
        reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.activities.isEmpty == true)
    }

    @Test func babiesKeepTheirOwnMeasurementsTimersAndReminders() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(in: folder)
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        var first = profile()
        first.avatarData = Data(repeating: 17, count: 200_000)
        _ = try await provider.apply(.createBaby(first))
        let activity = CareActivity(kind: .milk, value: "120", unit: "ml")
        var measurement = BodyMeasurement(weight: 9.3, height: nil, headCircumference: nil, method: "Nằm đo", notes: "Trước cữ sữa")
        let sleep = Date().addingTimeInterval(-1800)
        let reminder = MedicationReminder(name: "Thuốc theo đơn", amount: "2,5")
        _ = try await provider.apply(.saveActivities(babyID: first.id, entries: [activity]))
        _ = try await provider.apply(.saveMeasurement(babyID: first.id, measurement: measurement))
        measurement.height = 73
        _ = try await provider.apply(.saveMeasurement(babyID: first.id, measurement: measurement))
        _ = try await provider.apply(.startSleep(babyID: first.id, date: sleep))
        _ = try await provider.apply(.saveReminder(babyID: first.id, reminder: reminder))
        let second = profile(name: "Bé Bình")
        var data = try await provider.apply(.createBaby(second))
        #expect(data.selectedBaby?.activities.isEmpty == true)
        #expect(data.selectedBaby?.sleepStartDate == nil)
        let secondEntry = CareActivity(kind: .bath, value: "Tắm nước ấm")
        _ = try await provider.apply(.saveActivities(babyID: second.id, entries: [secondEntry]))
        _ = try await provider.apply(.selectBaby(first.id))
        data = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(data.babies.count == 2)
        #expect(data.selectedBaby?.profile == first)
        #expect(data.selectedBaby?.activities == [activity])
        #expect(data.selectedBaby?.measurements == [measurement])
        #expect(data.selectedBaby?.sleepStartDate == sleep)
        #expect(data.selectedBaby?.medicationReminders == [reminder])
        #expect(data.babies.last?.activities == [secondEntry])
        #expect(data.babies.last?.measurements.isEmpty == true)
        #expect(data.babies.last?.medicationReminders.isEmpty == true)
    }

    @Test func deletingBabyRemovesItsDataAndLastDeletionReturnsToOnboarding() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(in: folder)
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        let first = profile(), second = profile(name: "Bé Bình")
        _ = try await provider.apply(.createBaby(first))
        _ = try await provider.apply(.saveActivities(babyID: first.id, entries: [CareActivity(kind: .bath, value: "Đã tắm")]))
        _ = try await provider.apply(.saveMeasurement(babyID: first.id, measurement: BodyMeasurement(weight: 9.2)))
        _ = try await provider.apply(.saveReminder(babyID: first.id, reminder: MedicationReminder(name: "Thuốc theo đơn", amount: "1")))
        _ = try await provider.apply(.createBaby(second))

        var reopened = try await provider.apply(.deleteBaby(first.id))
        #expect(reopened.babies.map(\.profile.id) == [second.id])
        #expect(reopened.selectedBabyID == second.id)
        #expect(reopened.hasOnboarded)
        reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.babies.map(\.profile.id) == [second.id])

        _ = try await provider.apply(.deleteBaby(second.id))
        reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.babies.isEmpty)
        #expect(reopened.selectedBabyID == nil)
        #expect(!reopened.hasOnboarded)
    }

    @Test func batchRejectsAllRecordsAndKeepsSleepTimerWhenOneEntryIsInvalid() async throws {
        let provider = memorySwiftData()
        let baby = profile()
        _ = try await provider.apply(.createBaby(baby))
        let start = Date().addingTimeInterval(-1800)
        let before = try await provider.apply(.startSleep(babyID: baby.id, date: start))
        let sleep = CareActivity(kind: .sleep, date: start, value: "30", unit: "phút")
        let invalid = CareActivity(kind: .milk, value: "-1", unit: "ml")
        await #expect(throws: CareDataError.self) {
            try await provider.apply(.saveActivities(babyID: baby.id, entries: [sleep, invalid], finishingSleep: start))
        }
        #expect(try await provider.load() == before)
        let after = try await provider.apply(.saveActivities(babyID: baby.id, entries: [sleep], finishingSleep: start))
        #expect(after.selectedBaby?.sleepStartDate == nil)
        #expect(try await provider.load() == after)
    }

    @Test func medicationCompletionAndEndEpisodeCommitTogether() async throws {
        let provider = memorySwiftData()
        let baby = profile()
        _ = try await provider.apply(.createBaby(baby))
        _ = try await provider.apply(.startIllness(babyID: baby.id, title: "Theo dõi", date: Date().addingTimeInterval(-3600)))
        let reminder = MedicationReminder(name: "Thuốc theo đơn", amount: "2,5", episodeOnly: true)
        let independent = MedicationReminder(name: "Lịch riêng", amount: "1")
        _ = try await provider.apply(.saveReminder(babyID: baby.id, reminder: reminder))
        _ = try await provider.apply(.saveReminder(babyID: baby.id, reminder: independent))
        let wrong = CareActivity(kind: .medicine, value: "2,5", unit: "ml", detail: "Thuốc khác")
        var data = try await provider.apply(.saveActivities(babyID: baby.id, entries: [wrong], completingReminderID: reminder.id))
        #expect(data.selectedBaby?.medicationReminders.first?.enabled == true)
        let matching = CareActivity(kind: .medicine, value: "2.5", unit: "ml", detail: "thuốc theo đơn")
        _ = try await provider.apply(.saveActivities(babyID: baby.id, entries: [matching], completingReminderID: reminder.id))
        data = try await provider.load()
        #expect(data.selectedBaby?.activities.count == 2)
        #expect(data.selectedBaby?.medicationReminders.first?.enabled == false)
        _ = try await provider.apply(.saveReminder(babyID: baby.id, reminder: reminder))
        _ = try await provider.apply(.endIllness(babyID: baby.id))
        data = try await provider.load()
        #expect(data.selectedBaby?.isTrackingIllness == false)
        #expect(data.selectedBaby?.medicationReminders.first?.enabled == false)
        #expect(data.selectedBaby?.medicationReminders.last?.enabled == true)
        _ = try await provider.apply(.deleteReminder(babyID: baby.id, reminderID: independent.id))
        #expect(try await provider.load().selectedBaby?.medicationReminders.count == 1)
    }

    @Test func recordIdentityCannotMoveBetweenBabies() async throws {
        let provider = memorySwiftData()
        let first = profile(), second = profile(name: "Bé thứ hai")
        _ = try await provider.apply(.createBaby(first))
        _ = try await provider.apply(.createBaby(second))
        let entry = CareActivity(kind: .bath, value: "Tắm bé")
        let before = try await provider.apply(.saveActivities(babyID: first.id, entries: [entry]))
        await #expect(throws: CareDataError.self) {
            try await provider.apply(.saveActivities(babyID: second.id, entries: [entry]))
        }
        #expect(try await provider.load() == before)
    }

    @Test func legacyJSONImportsOnceWithoutChangingOriginal() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(in: folder)
        let sourceURL = try #require(configuration.legacyJSONURL)
        let fixture = legacyFixture()
        let bytes = try JSONEncoder().encode(fixture)
        try bytes.write(to: sourceURL)
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        let imported = try await provider.load()
        #expect(imported.babies.count == 2)
        #expect(imported.selectedBaby?.profile == fixture.baby)
        #expect(imported.selectedBaby?.activities == fixture.archives[fixture.baby.id.uuidString]?.activities)
        #expect(imported.selectedBaby?.measurements == fixture.archives[fixture.baby.id.uuidString]?.measurements)
        #expect(imported.selectedBaby?.medicationReminders == fixture.archives[fixture.baby.id.uuidString]?.medicationReminders)
        #expect(imported.selectedBaby?.sleepStartDate == fixture.archives[fixture.baby.id.uuidString]?.sleepStartDate)
        #expect(imported.selectedBaby?.isTrackingIllness == true)
        #expect(imported.babies.last?.activities.count == 1)
        #expect(try Data(contentsOf: sourceURL) == bytes)

        var edited = fixture.baby
        edited.name = "Tên mới sau chuyển đổi"
        _ = try await provider.apply(.updateBaby(edited))
        let reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.profile == edited)
        #expect(reopened.selectedBaby?.activities.count == 1)
        #expect(reopened.babies.count == 2)
        #expect(try Data(contentsOf: sourceURL) == bytes)
    }

    @Test func invalidLegacyFileBlocksWritesAndCanBeRetriedAfterRecovery() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = configuration(in: folder)
        let url = try #require(configuration.legacyJSONURL)
        let original = Data("not a valid JSON snapshot".utf8)
        try original.write(to: url)
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        await #expect(throws: CareDataError.self) { try await provider.load() }
        await #expect(throws: CareDataError.self) { try await provider.apply(.createBaby(profile())) }
        #expect(try Data(contentsOf: url) == original)
        // Simulate explicitly restoring a valid backup; the failed import did not set the marker.
        let fixture = legacyFixture()
        try JSONEncoder().encode(fixture).write(to: url)
        let restored = try await provider.load()
        #expect(restored.selectedBaby?.profile == fixture.baby)
        #expect(restored.babies.count == 2)
    }

    @Test func startupFailureKeepsViewModelRetryable() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let blocked = folder.appending(path: "occupied")
        try Data("keep this file".utf8).write(to: blocked)
        let configuration = CarePersistenceConfiguration(storeURL: blocked.appending(path: "database.store"))
        let model = BabyCareViewModel(provider: SwiftDataCareDataProvider(configuration: configuration))
        #expect(await model.send(.load) == false)
        #expect(model.state.phase == .failed)
        #expect(model.state.error != nil)
        #expect(await model.send(.commit(.createBaby(profile()))) == false)
        #expect(try Data(contentsOf: blocked) == Data("keep this file".utf8))
        try FileManager.default.removeItem(at: blocked)
        #expect(await model.send(.load))
        #expect(model.state.phase == .ready)
        #expect(model.state.error == nil)
    }

    @Test func failedProviderWriteDoesNotPublishOrTriggerNotifications() async throws {
        let provider = ControlledProvider()
        let notifications = RecordingReminderService()
        let model = BabyCareViewModel(provider: provider, notifications: notifications)
        #expect(await model.send(.load))
        let before = model.state.database
        let callsAfterLoad = notifications.calls
        await provider.setFailWrites(true)
        let baby = profile()
        #expect(await model.send(.commit(.createBaby(baby))) == false)
        #expect(model.state.database == before)
        #expect(model.state.error != nil)
        #expect(!model.state.isSaving)
        #expect(notifications.calls == callsAfterLoad)
        await provider.setFailWrites(false)
        #expect(await model.send(.commit(.createBaby(baby))))
        #expect(model.baby == baby)
        #expect(model.state.error == nil)
        #expect(notifications.calls == callsAfterLoad + 1)
    }

    @Test func delayedProviderPublishesOnlyAfterCommitAndRejectsOverlappingAction() async throws {
        let provider = ControlledProvider()
        let model = BabyCareViewModel(provider: provider)
        #expect(await model.send(.load))
        await provider.setDelayWrites(true)
        let baby = profile()
        let saving = Task { await model.send(.commit(.createBaby(baby))) }
        while await !provider.isWaiting { await Task.yield() }
        #expect(model.state.isSaving)
        #expect(model.babies.isEmpty)
        #expect(await model.send(.commit(.createBaby(profile(name: "Trùng thao tác")))) == false)
        await provider.release()
        #expect(await saving.value)
        #expect(model.babies == [baby])
        #expect(!model.state.isSaving)
    }

    @Test func eitherProviderSupportsSameViewModelWithoutViewChanges() async throws {
        let baby = profile()
        let providers: [any CareDataProvider] = [InMemoryCareDataProvider(), memorySwiftData()]
        let entry = CareActivity(kind: .water, value: "20", unit: "ml")
        for provider in providers {
            let model = BabyCareViewModel(provider: provider)
            #expect(await model.send(.load))
            #expect(await model.send(.commit(.createBaby(baby))))
            #expect(await model.send(.commit(.saveActivities(babyID: baby.id, entries: [entry]))))
            let reopened = BabyCareViewModel(provider: provider)
            #expect(await reopened.send(.load))
            #expect(reopened.baby == baby)
            #expect(reopened.activities == [entry])
        }
    }

    @Test func formActionsValidateDraftAndKeepStableIDForRetry() throws {
        let form = ActivityFormViewModel(kind: .milk)
        form.send(.value("120"))
        #expect(form.makeEntry()?.numericValue == 120)
        form.send(.detail("Bú mẹ"))
        #expect(form.state.value.isEmpty)
        #expect(form.state.unit == "phút")
        #expect(form.makeEntry() == nil)
        form.send(.value("12,5"))
        let entry = try #require(form.makeEntry())
        #expect(entry.numericValue == 12.5)
        #expect(form.makeEntry()?.id == entry.id)
        #expect(form.state.dirty)
        form.send(.loadingPhotos(true))
        #expect(form.makeEntry() == nil)
        form.send(.loadingPhotos(false))
        form.send(.value("nan"))
        #expect(form.makeEntry() == nil)
        let medicine = ActivityFormViewModel(kind: .medicine)
        medicine.send(.value("2"))
        #expect(medicine.makeEntry() == nil)
        medicine.send(.detail("Thuốc theo đơn"))
        medicine.send(.unit("ml"))
        #expect(medicine.makeEntry() != nil)
    }

    private func profile(name: String = "Bé An") -> BabyProfile {
        BabyProfile(name: name, birthDate: Date().addingTimeInterval(-365 * 86400), gender: .girl)
    }
    private func memorySwiftData() -> SwiftDataCareDataProvider {
        SwiftDataCareDataProvider(configuration: CarePersistenceConfiguration(storeURL: URL.temporaryDirectory.appending(path: UUID().uuidString), inMemory: true))
    }
    private func temporaryFolder() throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "BabyCareTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private func configuration(in folder: URL) -> CarePersistenceConfiguration {
        CarePersistenceConfiguration(storeURL: folder.appending(path: "BabyCare.store"), legacyJSONURL: folder.appending(path: "care-data.json"))
    }
    private func legacyFixture() -> LegacyJSONMigration.LegacySnapshot {
        var first = profile()
        first.avatarData = Data("avatar".utf8)
        let second = profile(name: "Bé Bình")
        let now = Date()
        let archive = LegacyJSONMigration.LegacyArchive(
            activities: [CareActivity(kind: .milk, date: now, value: "120", unit: "ml", attachments: [Data("photo".utf8)])],
            measurements: [BodyMeasurement(date: now, weight: 9.3, height: 73, method: "Nằm đo", notes: "Ghi chú")],
            isTrackingIllness: true, illnessTitle: "Đang theo dõi", illnessStartDate: now.addingTimeInterval(-7200),
            sleepStartDate: now.addingTimeInterval(-1800), medicationReminders: [MedicationReminder(name: "Thuốc theo đơn", amount: "2,5", episodeOnly: true)])
        let secondArchive = LegacyJSONMigration.LegacyArchive(activities: [CareActivity(kind: .bath, value: "Tắm bé")],
            measurements: [], isTrackingIllness: false, illnessTitle: "", illnessStartDate: now, medicationReminders: [])
        return LegacyJSONMigration.LegacySnapshot(baby: first, babies: [first, second], hasOnboarded: true,
            archives: [first.id.uuidString: archive, second.id.uuidString: secondArchive])
    }
}

private actor ControlledProvider: CareDataProvider {
    private var database = CareDatabase()
    private var failWrites = false
    private var delayWrites = false
    private var continuation: CheckedContinuation<Void, Never>?
    var isWaiting: Bool { continuation != nil }
    func setFailWrites(_ value: Bool) { failWrites = value }
    func setDelayWrites(_ value: Bool) { delayWrites = value }
    func release() { continuation?.resume(); continuation = nil }
    func load() async throws -> CareDatabase { database }
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase {
        if failWrites { throw CareDataError.invalidInput("Giả lập lỗi từ provider") }
        if delayWrites { await withCheckedContinuation { continuation = $0 } }
        database = try database.applying(mutation)
        return database
    }
}

@MainActor private final class RecordingReminderService: CareReminderService {
    var calls = 0
    func reconcile(previous: CareDatabase, current: CareDatabase) async -> String? { calls += 1; return nil }
}
