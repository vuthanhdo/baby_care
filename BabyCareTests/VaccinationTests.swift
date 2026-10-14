import Foundation
import SwiftData
import Testing
@testable import BabyCare

@MainActor struct VaccinationTests {
    private func baby() -> BabyProfile { BabyProfile(name: "Test", birthDate: Date(timeIntervalSince1970: 1_700_000_000)) }
    private func record() -> VaccinationRecord {
        VaccinationRecord(vaccineName: "Vaccine", date: Date().addingTimeInterval(-86400), nextDoseDate: Date().addingTimeInterval(86400 * 30), clinic: "Clinic", notes: "Notes", reminderEnabled: true, reminderDate: Date().addingTimeInterval(86400 * 29))
    }
    @Test func reducerOwnershipCompletionAndBirthDate() throws {
        let first = baby(), second = baby()
        var db = try CareDatabase().applying(.createBaby(first)).applying(.createBaby(second))
        let one = record()
        db = try db.applying(.saveVaccination(babyID: first.id, record: one))
        #expect(throws: CareDataError.self) { try db.applying(.saveVaccination(babyID: second.id, record: one)) }
        var next = one; next.id = UUID(); next.doseNumber = 2; next.date = Date().addingTimeInterval(-3600)
        db = try db.applying(.saveVaccination(babyID: first.id, record: next, completingID: one.id))
        #expect(db.babies[0].vaccinations.first?.id == next.id)
        #expect(db.babies[0].vaccinations.last?.reminderEnabled == false)
        #expect(db.babies[0].vaccinations.last?.nextDoseDate == nil)
        var profile = first; profile.birthDate = Date()
        #expect(throws: CareDataError.self) { try db.applying(.updateBaby(profile)) }
        db = try db.applying(.deleteVaccination(babyID: first.id, vaccinationID: next.id))
        #expect(db.babies[0].vaccinations.count == 1)
        #expect(db.babies[1].vaccinations.isEmpty)
    }
    @Test func validationAndElapsedReminderReplay() throws {
        let profile = baby(); var entry = record()
        entry.doseNumber = 0
        #expect(throws: CareDataError.self) { try CareValidation.vaccination(entry, birthDate: profile.birthDate) }
        entry = record(); entry.reminderDate = entry.nextDoseDate
        #expect(throws: CareDataError.self) { try CareValidation.vaccination(entry, birthDate: profile.birthDate) }
        entry = record(); entry.reminderDate = Date().addingTimeInterval(-10)
        try CareValidation.vaccination(entry, birthDate: profile.birthDate)
        entry.date = profile.birthDate.addingTimeInterval(-1)
        #expect(throws: CareDataError.self) { try CareValidation.vaccination(entry, birthDate: profile.birthDate) }
    }
    @Test func oldSnapshotAndQueuedProposalDecode() throws {
        let db = try CareDatabase().applying(.createBaby(baby()))
        let state = CloudCacheState(snapshot: CloudSnapshot(database: db), outbox: [PendingCloudWrite(mutation: .selectBaby(db.selectedBabyID!), envelope: CloudEnvelope(p_family_id: UUID(), p_changes: []), proposed: db)])
        let data = try JSONEncoder().encode(state)
        func withoutVaccinations(_ object: Any) -> Any {
            if var dictionary = object as? [String: Any] {
                dictionary.removeValue(forKey: "vaccinations")
                return dictionary.mapValues { withoutVaccinations($0) }
            }
            if let array = object as? [Any] { return array.map { withoutVaccinations($0) } }
            return object
        }
        let legacy = try JSONSerialization.data(withJSONObject: withoutVaccinations(JSONSerialization.jsonObject(with: data)))
        let decoded = try JSONDecoder().decode(CloudCacheState.self, from: legacy)
        #expect(decoded.snapshot?.database == db)
        #expect(decoded.queuedWrites.first?.proposed == db)
        #expect(decoded.queuedWrites.first?.envelope.p_operation_id == state.queuedWrites.first?.envelope.p_operation_id)
    }
    @Test func v1StoreMigratesAndVaccinationsSurviveEditsAndReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Care.store"), profile = baby()
        try seedV1(url: url, profile: profile)
        let config = CarePersistenceConfiguration(storeURL: url)
        let provider = SwiftDataCareDataProvider(configuration: config)
        let initial = try await provider.load()
        #expect(initial.selectedBabyID == profile.id)
        #expect(initial.hasOnboarded)
        #expect(initial.selectedBaby?.measurements.first?.weight == 8)
        #expect(initial.selectedBaby?.vaccinations.isEmpty == true)
        var entry = record()
        _ = try await provider.apply(.saveVaccination(babyID: profile.id, record: entry))
        var reopened = try await SwiftDataCareDataProvider(configuration: config).load()
        #expect(reopened.selectedBaby?.vaccinations == [entry])
        entry.clinic = "Updated clinic"
        _ = try await provider.apply(.saveVaccination(babyID: profile.id, record: entry))
        reopened = try await SwiftDataCareDataProvider(configuration: config).load()
        #expect(reopened.selectedBaby?.vaccinations == [entry])
        _ = try await provider.apply(.deleteVaccination(babyID: profile.id, vaccinationID: entry.id))
        reopened = try await SwiftDataCareDataProvider(configuration: config).load()
        #expect(reopened.selectedBaby?.vaccinations.isEmpty == true)
    }
    private func seedV1(url: URL, profile: BabyProfile) throws {
        let schema = Schema(versionedSchema: BabyCareSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let metadata = CareMetadataEntity(); metadata.selectedBabyID = profile.id; metadata.hasOnboarded = true; metadata.didImportLegacyJSON = true
        context.insert(metadata)
        let baby = BabyEntity(data: BabyData(profile: profile), sortOrder: 0)
        context.insert(baby)
        context.insert(MeasurementEntity(value: BodyMeasurement(weight: 8), baby: baby))
        try context.save()
    }
    @Test func cloudMappingRoundtripVersionsAndTombstones() throws {
        let profile = baby(), entry = record()
        let db = try CareDatabase().applying(.createBaby(profile)).applying(.saveVaccination(babyID: profile.id, record: entry))
        var tables: [String: [CloudRow]] = [:]
        for (entity, rows) in CloudMapping.rows(db) {
            tables[entity] = rows.map { id, values in
                var row = values; row["id"] = .id(id); row["baby_id"] = .id(profile.id); row["version"] = .number(1); row["deleted_at"] = .null
                return row
            }
        }
        let decoded = try CloudMapping.decode(tables, revision: 1, selected: profile.id)
        #expect(decoded.database.selectedBaby?.vaccinations.first?.vaccineName == entry.vaccineName)
        #expect(decoded.database.selectedBaby?.vaccinations.first?.doseNumber == 1)
        let deleted = try db.applying(.deleteVaccination(babyID: profile.id, vaccinationID: entry.id))
        let changes = try CloudMapping.changes(from: CloudSnapshot(database: db, versions: [CloudSnapshot.key("vaccinations",entry.id): 3]), to: deleted)
        #expect(changes.count == 1)
        #expect(changes.first?.deleted == true)
        #expect(changes.first?.baby_id == profile.id)
        #expect(changes.first?.expected_version == 3)
        tables["vaccinations"]?[0]["dose_number"] = .number(1.5)
        #expect(throws: CareDataError.self) { try CloudMapping.decode(tables, revision: 1, selected: profile.id) }
    }
    @Test func lateNotificationCompletionCannotRestoreInvalidatedSchedule() async throws {
        let center = SuspendedNotificationCenter()
        let service = LocalCareReminderService(scope: "late", center: center)
        let profile = baby()
        let db = try CareDatabase().applying(.createBaby(profile)).applying(.saveVaccination(babyID: profile.id, record: record()))
        let task = Task { await service.reconcile(previous: CareDatabase(), current: db) }
        while center.continuation == nil { await Task.yield() }
        await service.invalidate()
        center.release()
        _ = await task.value
        #expect(center.pending.isEmpty)
    }
    @Test func overlappingReconciliationsFinishWithLatestSchedule() async throws {
        let center = SuspendedNotificationCenter()
        let service = LocalCareReminderService(scope: "ordered", center: center)
        let profile = baby(), entry = record()
        let db = try CareDatabase().applying(.createBaby(profile)).applying(.saveVaccination(babyID: profile.id, record: entry))
        let empty = try db.applying(.deleteVaccination(babyID: profile.id, vaccinationID: entry.id))
        let first = Task { await service.reconcile(previous: CareDatabase(), current: db) }
        while center.continuation == nil { await Task.yield() }
        let second = Task { await service.reconcile(previous: db, current: empty) }
        center.release()
        _ = await first.value; _ = await second.value
        #expect(center.pending.isEmpty)
    }
    @Test func remindersReplaceAcrossRelaunchAndCancelWithoutTouchingOthers() async throws {
        let center = RecordingNotificationCenter()
        let profile = baby(); var entry = record()
        var db = try CareDatabase().applying(.createBaby(profile)).applying(.saveVaccination(babyID: profile.id, record: entry))
        center.pending["unrelated"] = Date()
        let first = LocalCareReminderService(scope: "test", center: center)
        #expect(await first.reconcile(previous: CareDatabase(), current: db) == nil)
        #expect(center.pending.count == 2)
        entry.reminderDate = Date().addingTimeInterval(1000)
        db = try db.applying(.saveVaccination(babyID: profile.id, record: entry))
        let restarted = LocalCareReminderService(scope: "test", center: center)
        #expect(await restarted.reconcile(previous: CareDatabase(), current: db) == nil)
        #expect(center.pending.count == 2)
        #expect(center.pending.values.contains(entry.reminderDate!))
        center.allowed = false
        #expect(await restarted.reconcile(previous: db, current: db) != nil)
        #expect(center.pending.count == 1)
        center.allowed = true
        _ = await restarted.reconcile(previous: db, current: db)
        await restarted.invalidate()
        #expect(center.pending.keys.sorted() == ["unrelated"])
        #expect(await restarted.reconcile(previous: CareDatabase(), current: db) == nil)
        #expect(center.pending.count == 1)
    }
}

@MainActor private final class RecordingNotificationCenter: CareNotificationCenter {
    var pending: [String: Date] = [:]
    var allowed = true
    func pendingIDs() async -> [String] { Array(pending.keys) }
    func authorize() async throws -> Bool { allowed }
    func add(_ notification: CareNotification) async throws { pending[notification.id] = notification.date }
    func remove(_ ids: [String]) { for id in ids { pending.removeValue(forKey: id) } }
}

@MainActor private final class SuspendedNotificationCenter: CareNotificationCenter {
    var pending: [String: Date] = [:]
    var continuation: CheckedContinuation<Void, Never>?
    func pendingIDs() async -> [String] { Array(pending.keys) }
    func authorize() async throws -> Bool { true }
    func add(_ notification: CareNotification) async throws {
        await withCheckedContinuation { continuation = $0 }
        pending[notification.id] = notification.date
    }
    func release() { continuation?.resume(); continuation = nil }
    func remove(_ ids: [String]) { for id in ids { pending.removeValue(forKey: id) } }
}
