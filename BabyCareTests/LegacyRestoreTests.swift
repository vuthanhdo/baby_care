import Foundation
import Testing
@testable import BabyCare

/// Restoring the caches the Supabase-era app left on the phone (`LegacyCloudRestore`) through the save path.
@MainActor struct LegacyRestoreTests {
    private let born = Date().addingTimeInterval(-86_400 * 200)

    /// A cache like a 1.3 (5) phone holds: entries spread over months, photos, a reminder that has since expired,
    /// an illness being followed, a sleep left running and one entry today's rules refuse.
    private func oldDatabase(entries: Int = 120) throws -> CareDatabase {
        var profile = BabyProfile(name: "Bé Sóc", birthDate: born)
        profile.avatarData = Data([0xff, 0xd8, 0xff, 0xd9])
        var database = try CareDatabase().applying(.createBaby(profile))
        let id = profile.id
        let activities = (0..<entries).map { index in
            CareActivity(kind: .milk, date: Date().addingTimeInterval(-3_600 * Double(index + 1)), value: "\(index + 60)", unit: "ml")
        }
        database = try database.applying(.saveActivities(babyID: id, entries: activities))
        database = try database.applying(.saveMeasurement(babyID: id, measurement: BodyMeasurement(date: born.addingTimeInterval(86_400), weight: 3.4)))
        database = try database.applying(.saveMeasurement(babyID: id, measurement: BodyMeasurement(date: born.addingTimeInterval(86_400 * 30), weight: 4.6)))
        database = try database.applying(.saveVaccination(babyID: id, record: VaccinationRecord(vaccineName: "BCG", date: born.addingTimeInterval(86_400))))
        database = try database.applying(.saveReminder(babyID: id, reminder: MedicationReminder(name: "Siro", amount: "2", unit: "ml")))
        database = try database.applying(.startIllness(babyID: id, title: "Ho", date: Date().addingTimeInterval(-86_400 * 2)))
        database = try database.applying(.startSleep(babyID: id, date: Date().addingTimeInterval(-600)))
        // Saved by an older rule or another clock: in the future now, so refused.
        database.babies[0].activities.append(CareActivity(kind: .milk, date: Date().addingTimeInterval(86_400), value: "90", unit: "ml"))
        // The reminder's time passed while the old server was down.
        database.babies[0].medicationReminders[0].nextDate = Date().addingTimeInterval(-86_400)
        return database
    }

    private func applying(_ mutations: [CareDataMutation], to database: CareDatabase) throws -> CareDatabase {
        try mutations.reduce(database) { try $0.applying($1) }
    }

    @Test func planRebuildsTheBabyWithNewIDsInSmallWrites() throws {
        let old = try oldDatabase(), account = UUID()
        let plan = LegacyCloudRestore.plan(restoring: old, into: CareDatabase(), account: account)
        // createBaby, 3 × entries (50 + 50 + 20), 2 measurements, 1 vaccination, 1 reminder, illness.
        #expect(plan.mutations.count == 9)
        #expect(plan.skipped == 1)
        let restored = try applying(plan.mutations, to: CareDatabase())
        let baby = try #require(restored.babies.first)
        #expect(restored.babies.count == 1 && restored.hasOnboarded)
        #expect(baby.profile.name == "Bé Sóc" && baby.profile.avatarData == old.babies[0].profile.avatarData)
        #expect(baby.profile.id != old.babies[0].profile.id)
        #expect(baby.activities.count == 120)
        #expect(Set(baby.activities.map(\.id)).isDisjoint(with: old.babies[0].activities.map(\.id)))
        #expect(baby.measurements.count == 2 && baby.vaccinations.count == 1)
        #expect(baby.medicationReminders.count == 1 && baby.medicationReminders[0].enabled == false)
        #expect(baby.isTrackingIllness && baby.illnessTitle == "Ho")
        #expect(baby.sleepStartDate == nil)
        for mutation in plan.mutations {
            if case .saveActivities(_, let entries, _, _) = mutation { #expect(entries.count <= LegacyCloudRestore.entriesPerWrite) }
        }
    }

    @Test func restoringAgainSendsOnlyWhatIsMissing() throws {
        let old = try oldDatabase(), account = UUID()
        let plan = LegacyCloudRestore.plan(restoring: old, into: CareDatabase(), account: account)
        // Interrupted after the baby and the first 50 entries.
        let partial = try applying(Array(plan.mutations.prefix(2)), to: CareDatabase())
        let rest = LegacyCloudRestore.plan(restoring: old, into: partial, account: account)
        #expect(rest.mutations == Array(plan.mutations.dropFirst(2)))
        let done = try applying(rest.mutations, to: partial)
        #expect(done == (try applying(plan.mutations, to: CareDatabase())))
        #expect(LegacyCloudRestore.plan(restoring: old, into: done, account: account).mutations.isEmpty)
    }

    @Test func anotherAccountGetsItsOwnIDs() throws {
        let old = try oldDatabase(entries: 3)
        let first = try applying(LegacyCloudRestore.plan(restoring: old, into: CareDatabase(), account: UUID()).mutations, to: CareDatabase())
        let second = try applying(LegacyCloudRestore.plan(restoring: old, into: CareDatabase(), account: UUID()).mutations, to: CareDatabase())
        #expect(first.babies[0].profile.id != second.babies[0].profile.id)
        #expect(Set(first.babies[0].activities.map(\.id)).isDisjoint(with: second.babies[0].activities.map(\.id)))
    }

    @Test func photosAreSpreadOverWrites() throws {
        let profile = BabyProfile(name: "Bé Na", birthDate: born)
        var old = try CareDatabase().applying(.createBaby(profile))
        let photo = Data([0xff, 0xd8, 0xff, 0xd9])
        let entries = (0..<10).map { index in
            CareActivity(kind: .bath, date: Date().addingTimeInterval(-3_600 * Double(index + 1)), value: CareActivity.recordedValue, attachments: [photo, photo, photo])
        }
        old = try old.applying(.saveActivities(babyID: profile.id, entries: entries))
        let sizes = LegacyCloudRestore.plan(restoring: old, into: CareDatabase(), account: UUID()).mutations.compactMap { mutation -> Int? in
            if case .saveActivities(_, let entries, _, _) = mutation { return entries.count }
            return nil
        }
        #expect(sizes == [6, 4]) // 18 + 12 photos, each write under 20.
    }

    @Test func aBabyOverTheLimitIsSkippedWithItsRecords() throws {
        var current = CareDatabase()
        for index in 0..<CareDatabase.maximumBabies { current = try current.applying(.createBaby(BabyProfile(name: "Bé \(index)", birthDate: born))) }
        let plan = LegacyCloudRestore.plan(restoring: try oldDatabase(entries: 3), into: current, account: UUID())
        #expect(plan.mutations.isEmpty)
        #expect(plan.skipped == LegacyCloudRestore.count(try oldDatabase(entries: 3)))
    }

    @Test func findsOldCachesPrefersUnsentWritesAndRemovesThem() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "legacy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let user = UUID(), family = UUID()
        let file = LegacyCloudRestore.directory(root: root).appending(path: "\(user.uuidString)/\(family.uuidString)/Cache.store")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let synced = try oldDatabase(entries: 2)
        var unsent = synced
        unsent.babies[0].activities.append(CareActivity(kind: .milk, date: Date().addingTimeInterval(-60), value: "70", unit: "ml"))
        let write = PendingCloudWrite(mutation: .selectBaby(synced.babies[0].profile.id),
                                      envelope: CloudEnvelope(p_family_id: family, p_changes: []), proposed: unsent)
        try await SwiftDataCloudCache(url: file).write(CloudCacheState(snapshot: CloudSnapshot(database: synced), outbox: [write]))
        // A cache of the new backend and an empty old one are not offered.
        try await SwiftDataCloudCache(userID: user, familyID: family, root: root).write(CloudCacheState(snapshot: CloudSnapshot(database: synced)))
        let empty = LegacyCloudRestore.directory(root: root).appending(path: "\(user.uuidString)/\(UUID().uuidString)/Cache.store")
        try FileManager.default.createDirectory(at: empty.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await SwiftDataCloudCache(url: empty).write(CloudCacheState(snapshot: CloudSnapshot()))

        let found = await LegacyCloudRestore.find(root: root)
        #expect(found.count == 1)
        let backup = try #require(found.first)
        #expect(backup.babyNames == ["Bé Sóc"])
        #expect(backup.recordCount == LegacyCloudRestore.count(unsent))
        let newest = unsent.babies.flatMap { $0.activities.map(\.date) + $0.measurements.map(\.date) + $0.vaccinations.map(\.date) }.max()
        #expect(backup.latestEntry == newest)
        #expect(await LegacyCloudRestore.database(at: backup.id) == unsent)

        LegacyCloudRestore.remove(backup, root: root)
        #expect(!FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path(percentEncoded: false)))
        #expect(await LegacyCloudRestore.find(root: root).isEmpty)
        LegacyCloudRestore.remove(nil, root: root)
        #expect(!FileManager.default.fileExists(atPath: LegacyCloudRestore.directory(root: root).path(percentEncoded: false)))
        // The new backend's cache is untouched.
        #expect(try await SwiftDataCloudCache(userID: user, familyID: family, root: root).read().snapshot?.database == synced)
    }

    @Test func viewModelRestoresEverythingAndClearsProgress() async throws {
        let old = try oldDatabase(entries: 60)
        let model = BabyCareViewModel(provider: InMemoryCareDataProvider(), initialData: CareDatabase())
        let plan = LegacyCloudRestore.plan(restoring: old, into: model.state.database, account: UUID())
        #expect(await model.restore(plan.mutations) == .done)
        #expect(model.state.database.babies.first?.activities.count == 60)
        #expect(model.state.restoring == nil && !model.state.isSaving)
    }

    @Test func viewModelStopsWhenASaveIsOnlyQueued() async throws {
        let old = try oldDatabase(entries: 60)
        let model = BabyCareViewModel(provider: QueuesAfterFirstSave(), initialData: CareDatabase())
        let plan = LegacyCloudRestore.plan(restoring: old, into: model.state.database, account: UUID())
        guard case .stopped = await model.restore(plan.mutations) else { Issue.record("expected a stop"); return }
        #expect(model.state.database.babies.count == 1)
        #expect(model.state.database.babies[0].activities.isEmpty)
        #expect(model.state.restoring == nil && !model.state.isSaving)
    }

    @Test func viewersCannotRestore() async throws {
        let model = BabyCareViewModel(provider: InMemoryCareDataProvider(), initialData: CareDatabase(), access: .viewer)
        let plan = LegacyCloudRestore.plan(restoring: try oldDatabase(entries: 1), into: CareDatabase(), account: UUID())
        guard case .stopped = await model.restore(plan.mutations) else { Issue.record("expected a refusal"); return }
        #expect(model.state.database.babies.isEmpty)
    }

    @Test func resetLinksAreRecognised() {
        #expect(SessionViewModel.isRecoveryLink(URL(string: "babycare://auth-callback?code=abc&type=recovery")!))
        #expect(!SessionViewModel.isRecoveryLink(URL(string: "babycare://auth-callback?code=abc")!))
    }
}

/// Saves the first write, then reports the rest as waiting for the network, like the cloud provider offline.
private actor QueuesAfterFirstSave: CareDataProvider {
    private var database = CareDatabase()
    private var saves = 0
    func load() async throws -> CareDatabase { database }
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase {
        database = try database.applying(mutation); saves += 1; return database
    }
    func status() async -> CareStorageStatus { saves > 0 ? .pending : .cloud }
}
