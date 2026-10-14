import Foundation
import Testing
import Supabase
@testable import BabyCare

@MainActor struct CloudProviderTests {
    private func baby() -> BabyProfile { BabyProfile(name: "Cloud test", birthDate: Date(timeIntervalSince1970: 1_700_000_000)) }
    private func snapshot(_ database: CareDatabase) -> CloudSnapshot {
        var result = CloudSnapshot(database: database, revision: 1)
        for (entity, rows) in CloudMapping.rows(database) {
            for id in rows.keys { result.versions[CloudSnapshot.key(entity,id)] = 1 }
        }
        return result
    }
    @Test func wireMappingKeepsCompoundSleepAndMedicationChangesTogether() throws {
        let p = baby(), start = Date().addingTimeInterval(-3600)
        let reminder = MedicationReminder(name: "Test", amount: "2,5", episodeOnly: true)
        var data = try CareDatabase().applying(.createBaby(p))
        data = try data.applying(.startSleep(babyID: p.id, date: start))
        data = try data.applying(.saveReminder(babyID: p.id, reminder: reminder))
        let sleep = CareActivity(kind: .sleep, date: start, value: "60", unit: "phút")
        let medicine = CareActivity(kind: .medicine, value: "2,5", unit: "ml", detail: "Test")
        let next = try data.applying(.saveActivities(babyID: p.id, entries: [sleep, medicine], finishingSleep: start, completingReminderID: reminder.id))
        let changes = try CloudMapping.changes(from: snapshot(data), to: next)
        #expect(changes.count == 4)
        #expect(changes.first { $0.entity == "baby_care_states" }?.data["sleep_start_date"] == .null)
        #expect(changes.first { $0.entity == "medication_reminders" }?.data["enabled"] == .bool(false))
        #expect(changes.first { $0.entity == "medication_reminders" }?.data["amount"] == .number(2.5))
        #expect(changes.allSatisfy { $0.baby_id == p.id })
        let bytes = try JSONEncoder().encode(CloudEnvelope(p_family_id: UUID(), p_changes: changes))
        let json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(json["p_api_version"] as? Int == 1)
        #expect(json["p_changes"] != nil)
    }
    @Test func deletesUseTombstonesAndCreationIncludesCareState() throws {
        let p = baby()
        let data = try CareDatabase().applying(.createBaby(p))
        let changes = try CloudMapping.changes(from: CloudSnapshot(), to: data)
        #expect(changes.map(\.entity) == ["babies", "baby_care_states"])
        #expect(changes.allSatisfy { $0.expected_version == 0 })
        let entry = CareActivity(kind: .bath, value: "Test")
        let before = try data.applying(.saveActivities(babyID: p.id, entries: [entry]))
        let after = try before.applying(.deleteActivity(babyID: p.id, activityID: entry.id))
        let deletion = try #require(CloudMapping.changes(from: snapshot(before), to: after).first)
        #expect(deletion.deleted && deletion.data.isEmpty && deletion.expected_version == 1)
    }
    @Test func sqlRowsDecodeDatesNullsVersionsAndFilterTombstones() throws {
        let p = baby()
        var tables: [String: [CloudRow]] = [:]
        let data = try CareDatabase().applying(.createBaby(p))
        for (entity, rows) in CloudMapping.rows(data) {
            tables[entity] = rows.map { id, row in
                row.merging(["id": .id(id), "baby_id": .id(p.id), "version": .number(3), "deleted_at": .null]) { _, new in new }
            }
        }
        let decoded = try CloudMapping.decode(tables, revision: 8, selected: p.id)
        #expect(decoded.database.selectedBaby?.profile == p)
        #expect(decoded.revision == 8)
        #expect(decoded.versions[CloudSnapshot.key("babies",p.id)] == 3)
        tables["babies"]?[0]["deleted_at"] = .date(Date())
        #expect(try CloudMapping.decode(tables, revision: 9, selected: p.id).database.babies.isEmpty)
    }
    @Test func mediaIsRejectedBeforeAnyNetworkWrite() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        _ = try await provider.load()
        var p = baby(); p.avatarData = Data([1,2,3])
        await #expect(throws: CareDataError.self) { try await provider.apply(.createBaby(p)) }
        #expect(await remote.requests.isEmpty)
    }
    @Test func supportedMediaIsAcceptedAndSentToMediaSync() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), family = UUID()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        _ = try await provider.load()
        var p = baby(); p.avatarData = Data([0xff, 0xd8, 0xff, 0xd9])
        let saved = try await provider.apply(.createBaby(p))
        #expect(saved.selectedBaby?.profile.avatarData == p.avatarData)
        #expect(await remote.mediaSyncCount == 1)
        #expect(await remote.requests.count == 1)
    }
    @Test func mediaRetryAndReselectKeepCorrectIdentity() throws {
        var p = baby(); p.avatarData = Data([0xff, 0xd8, 0xff, 0xd9])
        let database = try CareDatabase().applying(.createBaby(p))
        let family = UUID(), operation = UUID()
        let first = try CloudMediaPlan.desired(in: database, familyID: family, operationID: operation)
        let retry = try CloudMediaPlan.desired(in: database, familyID: family, operationID: operation)
        #expect(first[0].asset.id == retry[0].asset.id)
        let reselected = try CloudMediaPlan.desired(in: database, familyID: family, operationID: UUID())
        #expect(first[0].asset.id != reselected[0].asset.id)
        var ready = first[0].asset; ready.status = "ready"; ready.version = 2
        let unchanged = try CloudMediaPlan.desired(in: database, familyID: family, operationID: UUID(), existing: [ready])
        #expect(unchanged[0].asset.id == ready.id)
    }
    @Test func mediaTimeoutKeepsBytesAcrossProviderRecreation() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), family = UUID()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family, retryDelay: .seconds(3600))
        _ = try await provider.load()
        var p = baby(); p.avatarData = Data([0xff, 0xd8, 0xff, 0xd9])
        await remote.setMediaError(.offline)
        let visible = try await provider.apply(.createBaby(p))
        #expect(visible.selectedBaby?.profile.avatarData == p.avatarData)
        #expect(await provider.status() == .pending)
        let queued = try await cache.read()
        #expect(queued.queuedWrites.count == 1)
        let persisted = try JSONDecoder().decode(CloudCacheState.self, from: JSONEncoder().encode(queued))
        #expect(persisted.queuedWrites[0].proposed.selectedBaby?.profile.avatarData == p.avatarData)
        await provider.invalidate()
        await remote.setMediaError(nil)
        let reopened = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        let synced = try await reopened.syncPendingWrites()
        #expect(synced.selectedBaby?.profile.avatarData == p.avatarData)
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.commitCount == 1)
    }
    @Test func consentRequiredKeepsDurableOutboxForReconsent() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), family = UUID()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        _ = try await provider.load()
        await remote.setApplyError(.consentRequired)
        let profile = baby()
        await #expect(throws: CloudError.consentRequired) { try await provider.apply(.createBaby(profile)) }
        let pending = try await cache.read()
        #expect(pending.queuedWrites.count == 1 && pending.snapshot != nil)
        let operation = try #require(pending.queuedWrites.first?.envelope.p_operation_id)
        await provider.invalidate()
        await remote.setApplyError(nil)
        let restored = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        #expect(try await restored.syncPendingWrites().selectedBaby?.profile == profile)
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.requests.last?.p_operation_id == operation)
    }
    @Test func timeoutAfterCommitRetriesSameOperationAfterProviderRecreation() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), family = UUID()
        let first = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        _ = try await first.load()
        await remote.timeoutOnce()
        let mutation = CareDataMutation.createBaby(baby())
        let optimistic = try await first.apply(mutation)
        #expect(optimistic.babies.count == 1)
        let staged = try await cache.read()
        #expect(staged.snapshot?.database.babies.isEmpty == true)
        #expect(staged.queuedWrites.count == 1)
        let reopened = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        let saved = try await reopened.syncPendingWrites()
        #expect(saved.babies.count == 1)
        let requests = await remote.requests
        #expect(requests.count == 2 && requests[0].p_operation_id == requests[1].p_operation_id)
        #expect(await remote.commitCount == 1)
        #expect(try await cache.read().queuedWrites.isEmpty)
    }
    @Test func legacySinglePendingJournalMigratesIntoOutbox() throws {
        struct LegacyState: Codable {
            var snapshot: CloudSnapshot?
            var pending: PendingCloudWrite?
        }
        let family = UUID()
        let profile = baby()
        let base = snapshot(CareDatabase())
        let proposed = try base.database.applying(.createBaby(profile))
        let write = PendingCloudWrite(mutation: .createBaby(profile),
            envelope: CloudEnvelope(p_family_id: family,
                p_changes: try CloudMapping.changes(from: base, to: proposed)), proposed: proposed)
        let bytes = try JSONEncoder().encode(LegacyState(snapshot: base, pending: write))
        let decoded = try JSONDecoder().decode(CloudCacheState.self, from: bytes)
        #expect(decoded.queuedWrites.count == 1)
        #expect(decoded.queuedWrites[0].envelope.p_operation_id == write.envelope.p_operation_id)
    }
    @Test func multipleOfflineWritesQueueAndFlushInOrder() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        _ = try await provider.load()
        await remote.setApplyError(.offline)
        let first = baby()
        let firstState = try await provider.apply(.createBaby(first))
        let second = BabyProfile(name: "Second", birthDate: first.birthDate)
        let secondState = try await provider.apply(.createBaby(second))
        #expect(firstState.babies.count == 1)
        #expect(secondState.babies.count == 2)
        #expect(try await cache.read().queuedWrites.count == 2)
        #expect(await provider.status() == .pending)
        await remote.setApplyError(nil)
        let synced = try await provider.syncPendingWrites()
        #expect(synced.babies.count == 2)
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.commitCount == 2)
    }
    @Test func offlineActivityIsVisibleDurableAndSyncsWhenOnline() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), family = UUID()
        let profile = baby()
        let data = try CareDatabase().applying(.createBaby(profile))
        try await cache.write(CloudCacheState(snapshot: snapshot(data)))
        await remote.setFetchError(.offline)
        await remote.setApplyError(.offline)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        #expect(try await provider.load() == data)
        #expect(await provider.status() == .cached)
        let activity = CareActivity(kind: .milk, value: "120", unit: "ml")
        let saved = try await provider.apply(.saveActivities(babyID: profile.id, entries: [activity]))
        #expect(saved.selectedBaby?.activities == [activity])
        #expect(await provider.status() == .pending)
        let disk = try await cache.read()
        #expect(disk.snapshot?.database.selectedBaby?.activities.isEmpty == true)
        #expect(disk.queuedWrites.last?.proposed.selectedBaby?.activities == [activity])
        await remote.setFetchError(nil)
        await remote.setApplyError(nil)
        // Recreate the provider to model killing the app while it is offline.
        let reopened = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family)
        let synced = try await reopened.syncPendingWrites()
        #expect(synced.selectedBaby?.activities == [activity])
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.commitCount == 1)
    }
    @Test func queuedWriteRetriesAutomaticallyWhenNetworkReturns() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache()
        let profile = baby()
        try await cache.write(CloudCacheState(snapshot: snapshot(try CareDatabase().applying(.createBaby(profile)))))
        await remote.setFetchError(.offline)
        await remote.setApplyError(.offline)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID(), retryDelay: .milliseconds(20))
        _ = try await provider.load()
        _ = try await provider.apply(.saveActivities(babyID: profile.id,
            entries: [CareActivity(kind: .bath, value: "Đã tắm")]))
        await remote.setApplyError(nil)
        for _ in 0..<100 where await remote.commitCount == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await remote.commitCount == 1)
        #expect(try await cache.read().queuedWrites.isEmpty)
    }
    @Test func deniedAccessPurgesCacheInsteadOfFallback() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache()
        try await cache.write(CloudCacheState(snapshot: snapshot(try CareDatabase().applying(.createBaby(baby())))))
        await remote.setFetchError(.accessDenied)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        await #expect(throws: CloudError.accessDenied) { try await provider.load() }
        #expect(try await cache.read().snapshot == nil)
    }
    @Test func cacheFailureAfterConfirmedCommitStillReturnsSavedState() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache()
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        _ = try await provider.load()
        await cache.failAfterAdditionalWrites(2) // Pending journal succeeds; committed snapshot fails.
        let saved = try await provider.apply(.createBaby(baby()))
        #expect(saved.babies.count == 1)
        #expect(await provider.status() == .cacheWarning)
        #expect(try await cache.read().queuedWrites.count == 1) // Safe idempotent recovery on relaunch.
    }
    @Test func babyDeletionUsesDedicatedRPCAndPurgesSensitiveCache() async throws {
        let remote = FakeCloudRemote(), cache = FakeCloudCache(), profile = baby()
        let database = try CareDatabase().applying(.createBaby(profile))
        try await cache.write(CloudCacheState(snapshot: snapshot(database)))
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())

        let deleted = try await provider.apply(.deleteBaby(profile.id))

        #expect(deleted.babies.isEmpty)
        #expect(!deleted.hasOnboarded)
        #expect(await remote.deletedBabyIDs == [profile.id])
        #expect(try await cache.read().snapshot == nil)
        #expect(try await cache.read().queuedWrites.isEmpty)
    }
    @Test func differentAccountsAndFamiliesHaveSeparateSwiftDataStores() async throws {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = UUID(), b = UUID(), family = UUID()
        let first = SwiftDataCloudCache(userID: a, familyID: family, root: root)
        let state = CloudCacheState(snapshot: snapshot(try CareDatabase().applying(.createBaby(baby()))))
        try await first.write(state)
        #expect(try await SwiftDataCloudCache(userID: a, familyID: family, root: root).read().snapshot?.database == state.snapshot?.database)
        #expect(try await SwiftDataCloudCache(userID: b, familyID: family, root: root).read().snapshot == nil)
        #expect(try await SwiftDataCloudCache(userID: a, familyID: UUID(), root: root).read().snapshot == nil)
    }
    @Test func signedOutViewModelRejectsLateLoad() async throws {
        let provider = DelayedCloudLoad()
        let model = BabyCareViewModel(provider: provider)
        let loading = Task { await model.send(.load) }
        while await !provider.waiting { await Task.yield() }
        await model.deactivate()
        await provider.release(try CareDatabase().applying(.createBaby(baby())))
        #expect(await loading.value == false)
        #expect(model.state.database.babies.isEmpty)
        #expect(await model.send(.load) == false)
    }
    @Test func sessionLeaseCannotBeReusedAfterInvalidation() async throws {
        let lease = CloudSessionLease()
        try await lease.check(); await lease.invalidate()
        await #expect(throws: CloudError.signedOut) { try await lease.check() }
    }
}

private actor FakeCloudCache: CareCloudCache {
    private var state = CloudCacheState()
    private var writes = 0
    private var failingWrite: Int?
    func failAfterAdditionalWrites(_ value: Int) { failingWrite = writes + value }
    func read() throws -> CloudCacheState { state }
    func write(_ value: CloudCacheState) throws {
        writes += 1
        if writes == failingWrite { throw CocoaError(.fileWriteOutOfSpace) }
        state = value
    }
}
private actor FakeCloudRemote: CareCloudRemote {
    private(set) var requests: [CloudEnvelope] = []
    private(set) var commitCount = 0
    private var receipts: [UUID: CloudReceipt] = [:]
    private var timeout = false
    private var fetchError: CloudError?
    private var fetchedSnapshot = CloudSnapshot()
    func setSnapshot(_ snapshot: CloudSnapshot) { fetchedSnapshot = snapshot }
    private var applyError: CloudError?
    private(set) var deletedBabyIDs: [UUID] = []
    private(set) var mediaSyncCount = 0
    private var mediaError: CloudError?
    func setMediaError(_ error: CloudError?) { mediaError = error }
    func timeoutOnce() { timeout = true }
    func setFetchError(_ error: CloudError?) { fetchError = error }
    func setApplyError(_ error: CloudError?) { applyError = error }
    func invalidate() {}
    func fetch(selected: UUID?) throws -> CloudSnapshot {
        if let fetchError { throw fetchError }; return fetchedSnapshot
    }
    func apply(_ envelope: CloudEnvelope) throws -> CloudReceipt {
        requests.append(envelope)
        if let applyError { throw applyError }
        if let receipt = receipts[envelope.p_operation_id] { return receipt }
        commitCount += 1
        let receipt = CloudReceipt(operation_id: envelope.p_operation_id, revision: commitCount,
            records: envelope.p_changes.map { .init(entity: $0.entity, id: $0.id, version: $0.expected_version + 1) })
        receipts[envelope.p_operation_id] = receipt
        if timeout { timeout = false; throw CloudError.offline }
        return receipt
    }
    func deleteBaby(_ id: UUID) { deletedBabyIDs.append(id) }
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) throws -> CloudMediaSyncResult {
        mediaSyncCount += 1
        if let mediaError { throw mediaError }
        let uploads = try CloudMediaPlan.desired(in: next, familyID: UUID())
        let assets = uploads.map { upload in
            var asset = upload.asset; asset.version = 2; asset.status = "ready"; return asset
        }
        return CloudMediaSyncResult(assets: assets, revision: old.revision + 1, records: [])
    }
}
private actor DelayedCloudLoad: CareDataProvider {
    private var continuation: CheckedContinuation<CareDatabase, Never>?
    var waiting: Bool { continuation != nil }
    func load() async -> CareDatabase { await withCheckedContinuation { continuation = $0 } }
    func release(_ database: CareDatabase) { continuation?.resume(returning: database); continuation = nil }
    func apply(_ mutation: CareDataMutation) throws -> CareDatabase { throw CloudError.signedOut }
}


extension CloudProviderTests {
    @Test func vaccinationOfflineQueueSurvivesProviderRecreationAndRetries() async throws {
        let cache = FakeCloudCache(), remote = FakeCloudRemote(), family = UUID()
        let profile = BabyProfile(name: "Vaccine test", birthDate: Date().addingTimeInterval(-86400 * 100))
        let db = try CareDatabase().applying(.createBaby(profile))
        try await cache.write(CloudCacheState(snapshot: CloudSnapshot(database: db)))
        await remote.setApplyError(.offline)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family, retryDelay: .seconds(3600))
        let entry = VaccinationRecord(vaccineName: "Vaccine", date: Date().addingTimeInterval(-3600))
        let saved = try await provider.apply(.saveVaccination(babyID: profile.id, record: entry))
        #expect(saved.selectedBaby?.vaccinations == [entry])
        let pending = try await cache.read()
        #expect(pending.queuedWrites.count == 1)
        let operation = pending.queuedWrites[0].envelope.p_operation_id
        await provider.invalidate()
        await remote.setApplyError(nil)
        let reopened = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family, retryDelay: .seconds(3600))
        let synced = try await reopened.syncPendingWrites()
        #expect(synced.selectedBaby?.vaccinations == [entry])
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.requests.last?.p_operation_id == operation)
        #expect(await remote.requests.last?.p_changes.first?.entity == "vaccinations")
        await reopened.invalidate()
    }
}


extension CloudProviderTests {
    @Test func legacyBackendLoadsOtherDataAndBlocksOnlyVaccinationWrites() async throws {
        let cache = FakeCloudCache(), remote = FakeCloudRemote()
        let profile = baby()
        let database = try CareDatabase().applying(.createBaby(profile))
        var legacy = snapshot(database)
        legacy.supportsVaccinations = false
        await remote.setSnapshot(legacy)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        let model = BabyCareViewModel(provider: provider)
        #expect(await model.send(.load))
        #expect(model.state.phase == .ready)
        #expect(!model.state.vaccinationsAvailable)
        let record = VaccinationRecord(vaccineName: "Test", date: Date().addingTimeInterval(-3600))
        await #expect(throws: CloudError.vaccinationsUnavailable) {
            try await provider.apply(.saveVaccination(babyID: profile.id, record: record))
        }
        #expect(try await cache.read().queuedWrites.isEmpty)
        var edited = profile; edited.name = "Edited"
        _ = try await provider.apply(.updateBaby(edited))
        #expect(await remote.commitCount == 1)
        await remote.setSnapshot(snapshot(database))
        #expect(await model.send(.load))
        #expect(model.state.vaccinationsAvailable)
        await model.deactivate()
    }

    @Test func unsupportedFetchPreservesCachedVaccinationHistory() async throws {
        let cache = FakeCloudCache(), remote = FakeCloudRemote(), profile = baby()
        let database = try CareDatabase().applying(.createBaby(profile))
        let record = VaccinationRecord(vaccineName: "Cached", date: Date().addingTimeInterval(-3600))
        let saved = try database.applying(.saveVaccination(babyID: profile.id, record: record))
        try await cache.write(CloudCacheState(snapshot: snapshot(saved)))
        var legacy = snapshot(database); legacy.supportsVaccinations = false
        await remote.setSnapshot(legacy)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        #expect(try await provider.load().selectedBaby?.vaccinations == [record])
        #expect(try await cache.read().snapshot?.versions[CloudSnapshot.key("vaccinations",record.id)] == 1)
        await provider.invalidate()
    }

    @Test func queuedVaccinationSurvivesLegacyBackendAndRetriesAfterUpgrade() async throws {
        let cache = FakeCloudCache(), remote = FakeCloudRemote(), profile = baby(), family = UUID()
        let database = try CareDatabase().applying(.createBaby(profile))
        try await cache.write(CloudCacheState(snapshot: snapshot(database)))
        await remote.setApplyError(.offline)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: family, retryDelay: .seconds(3600))
        let record = VaccinationRecord(vaccineName: "Pending", date: Date().addingTimeInterval(-3600))
        let saved = try await provider.apply(.saveVaccination(babyID: profile.id, record: record))
        let operation = try #require(await cache.read().queuedWrites.first?.envelope.p_operation_id)
        await remote.setApplyError(.vaccinationsUnavailable)
        #expect(try await provider.load().selectedBaby?.vaccinations == [record])
        #expect(await provider.status() == .pending)
        #expect(await provider.supportsVaccinations() == false)
        #expect(try await cache.read().queuedWrites.count == 1)
        await remote.setApplyError(nil)
        await remote.setSnapshot(snapshot(saved))
        #expect(try await provider.load().selectedBaby?.vaccinations == [record])
        #expect(await provider.supportsVaccinations())
        #expect(try await cache.read().queuedWrites.isEmpty)
        #expect(await remote.requests.last?.p_operation_id == operation)
        await provider.invalidate()
    }

    @Test func onlyKnownLegacyVaccinationReadErrorIsRecoverable() {
        let legacy = PostgrestError(code: "22023", message: "Invalid read cursor")
        #expect(CloudError.isMissingVaccinationEntity(legacy, entity: "vaccinations"))
        #expect(!CloudError.isMissingVaccinationEntity(legacy, entity: "babies"))
        #expect(!CloudError.isMissingVaccinationEntity(PostgrestError(code: "42501", message: "Read access denied"), entity: "vaccinations"))
        #expect(!CloudError.isMissingVaccinationEntity(PostgrestError(code: "22023", message: "Invalid vaccination date"), entity: "vaccinations"))
    }
}


extension CloudProviderTests {
    @Test func cacheWithoutCapabilityRequiresSuccessfulFetchBeforeVaccinationWrite() async throws {
        let cache = FakeCloudCache(), remote = FakeCloudRemote(), profile = baby()
        let database = try CareDatabase().applying(.createBaby(profile))
        let bytes = try JSONEncoder().encode(snapshot(database))
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json.removeValue(forKey: "supportsVaccinations")
        let old = try JSONDecoder().decode(CloudSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.supportsVaccinations == nil)
        try await cache.write(CloudCacheState(snapshot: old))
        await remote.setFetchError(.offline)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID())
        #expect(try await provider.load().selectedBaby?.profile.id == profile.id)
        let record = VaccinationRecord(vaccineName: "Test", date: Date().addingTimeInterval(-3600))
        await #expect(throws: CloudError.vaccinationsUnavailable) {
            try await provider.apply(.saveVaccination(babyID: profile.id, record: record))
        }
        #expect(try await cache.read().queuedWrites.isEmpty)
        await remote.setFetchError(.accessDenied)
        await #expect(throws: CloudError.accessDenied) { try await provider.load() }
        #expect(try await cache.read().snapshot == nil)
        await provider.invalidate()
    }
}
