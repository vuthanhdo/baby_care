import Foundation
import Supabase
import Testing
@testable import BabyCare

@MainActor
struct SharedCareTests {
    @Test func inviteCodesAreForgivingAndLinkable() {
        #expect(CareInviteCode.normalize(" abcd-efgh ") == "ABCDEFGH")
        #expect(CareInviteCode.isComplete("abcd efgh") && !CareInviteCode.isComplete("ABCDEFG"))
        #expect(CareInviteCode.display("abcdefgh") == "ABCD EFGH")
        let link = CareInviteCode.link("abcd-efgh")
        #expect(link.absoluteString == "babycare://invite?code=ABCDEFGH")
        #expect(CareInviteCode.code(from: link) == "ABCDEFGH")
        #expect(CareInviteCode.code(from: URL(string: "babycare://auth-callback?code=ABCDEFGH")!) == nil)
        #expect(CareInviteCode.code(from: URL(string: "babycare://invite?code=ABC")!) == nil)
        let message = CareInviteCode.message(code: "ABCDEFGH", role: .caregiver)
        #expect(message.contains("ABCD EFGH") && message.contains("ct=invite") && message.contains("babycare://invite?code=ABCDEFGH"))
    }

    @Test func serverAnswersDecode() throws {
        let sharing = try JSONDecoder().decode(CloudFamilySharing.self, from: Data("""
        {"role":"owner","created_by":"00000000-0000-0000-0000-0000000000a1",
         "members":[{"user_id":"00000000-0000-0000-0000-0000000000a1","email":"a@example.invalid","role":"owner","joined_at":"2026-10-26T01:02:03.456789+00:00"}],
         "invites":[{"id":"00000000-0000-0000-0000-0000000000b1","role":"viewer","created_at":"2026-10-26T01:02:03+00:00","expires_at":"2026-10-28T01:02:03.5+00:00"}]}
        """.utf8))
        #expect(sharing.role == .owner && sharing.members.first?.email == "a@example.invalid" && sharing.invites.first?.role == .viewer)
        let created = try JSONDecoder().decode(CloudCreatedInvite.self, from: Data(#"{"id":"00000000-0000-0000-0000-0000000000b2","code":"ABCDEFGH","role":"caregiver","expires_at":"2026-10-28T01:02:03.123456+00:00"}"#.utf8))
        #expect(created.code == "ABCDEFGH" && created.invite.role == .caregiver)
        let joined = try JSONDecoder().decode(CloudInviteAnswer.self, from: Data(#"{"status":"joined","family_id":"00000000-0000-0000-0000-00000000aa10","owner_email":"a@example.invalid","role":"caregiver"}"#.utf8))
        #expect(joined.status == .joined && joined.problem == nil && joined.role == .caregiver)
        let refused = try JSONDecoder().decode(CloudInviteAnswer.self, from: Data(#"{"status":"rate_limited"}"#.utf8))
        #expect(refused.familyID == nil && refused.problem != nil)
        let families = try JSONDecoder().decode([CloudFamilySummary].self, from: Data(#"[{"id":"00000000-0000-0000-0000-00000000aa10","name":"Hồ sơ của tôi","revision":4,"role":"viewer","created_by":"00000000-0000-0000-0000-0000000000a1","owner_email":"a@example.invalid","member_count":2}]"#.utf8))
        #expect(families.first?.role == .viewer && families.first?.memberCount == 2)
    }

    @Test func permissionRefusalsAreNotTreatedAsRemoval() {
        for message in ["Write access denied", "Owner access required"] {
            guard case .rejected = CloudError.normalize(PostgrestError(code: "42501", message: message)) as? CloudError else {
                Issue.record("\(message) should be a refusal, not a lost membership"); continue
            }
        }
        #expect(CloudError.normalize(PostgrestError(code: "42501", message: "Read access denied")) as? CloudError == .accessDenied)
    }

    @Test func viewersOnlyReadAndCaregiversCannotDeleteBabies() async {
        let data = CarePreviewData.make()
        let entry = CareActivity(kind: .diaper, value: "Đi tiểu")
        let viewer = BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data, access: .viewer)
        let baby = viewer.baby.id
        let before = viewer.activities.count
        #expect(!(await viewer.send(.commit(.saveActivities(babyID: baby, entries: [entry])))))
        #expect(viewer.state.error != nil && viewer.activities.count == before)
        #expect(await viewer.send(.commit(.selectBaby(baby)))) // choosing a baby is not a write

        let caregiver = BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data, access: .caregiver)
        #expect(await caregiver.send(.commit(.saveActivities(babyID: baby, entries: [entry]))))
        #expect(!(await caregiver.send(.commit(.deleteBaby(baby)))))
        #expect(caregiver.babies.contains { $0.id == baby })
    }

    @Test func unchangedRevisionSkipsTheFullRead() async throws {
        let remote = RevisionRemote(), cache = MemoryCloudCache()
        let profile = BabyProfile(name: "Shared", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        var snapshot = CloudSnapshot(database: try CareDatabase().applying(.createBaby(profile)), revision: 5)
        snapshot.readVersion = CloudMapping.readVersion
        await remote.set(snapshot)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID(), retryDelay: .seconds(3600))
        #expect(try await provider.load().selectedBaby?.profile == profile)
        _ = try await provider.load()
        #expect(await remote.fetches == 1) // same revision: the cached rows are current
        snapshot.revision = 6
        await remote.set(snapshot)
        _ = try await provider.load()
        #expect(await remote.fetches == 2)
        // A cache written before read versions were recorded may lack newer kinds: it is read again in full.
        var old = try await cache.read(); old.snapshot?.readVersion = nil
        try await cache.write(old)
        let reopened = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID(), retryDelay: .seconds(3600))
        _ = try await reopened.load()
        #expect(await remote.fetches == 3)
        await provider.invalidate(); await reopened.invalidate()
    }

    @Test func removalReportsDroppedChangesAndSignalsTheSession() async throws {
        let remote = RevisionRemote(), cache = MemoryCloudCache()
        let profile = BabyProfile(name: "Shared", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        var snapshot = CloudSnapshot(database: try CareDatabase().applying(.createBaby(profile)), revision: 1)
        snapshot.readVersion = CloudMapping.readVersion
        await remote.set(snapshot)
        let provider = SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID(), retryDelay: .seconds(3600))
        let model = BabyCareViewModel(provider: provider, access: .caregiver)
        #expect(await model.send(.load))
        await remote.setApplyError(.offline)
        #expect(await model.send(.commit(.saveActivities(babyID: profile.id, entries: [CareActivity(kind: .diaper, value: "Thay tã")]))))
        #expect(try await cache.read().queuedWrites.count == 1)

        await remote.setApplyError(.accessDenied)
        #expect(!(await model.send(.load)))
        #expect(model.state.phase == .failed)
        let reason = try #require(model.state.accessLost)
        #expect(reason.contains("1"))
        let cleared = await cache.read()
        #expect(cleared.queuedWrites.isEmpty && cleared.snapshot == nil)
        await model.deactivate()
    }

    @Test func refreshKeepsTheScreensAndWaitsForStaleData() async throws {
        let remote = RevisionRemote(), cache = MemoryCloudCache()
        let profile = BabyProfile(name: "Shared", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        await remote.set(CloudSnapshot(database: try CareDatabase().applying(.createBaby(profile)), revision: 1))
        let model = BabyCareViewModel(provider: SupabaseCareDataProvider(remote: remote, cache: cache, familyID: UUID(), retryDelay: .seconds(3600)))
        #expect(await model.send(.load))
        await model.refreshIfStale(now: Date())
        #expect(await remote.fetches == 1) // just loaded
        await model.refreshIfStale(now: Date().addingTimeInterval(BabyCareViewModel.refreshInterval + 1))
        #expect(await remote.fetches == 2 && model.state.phase == .ready && !model.state.isRefreshing)
        await model.deactivate()
    }
}

extension SharedCareTests {
    /// Pull to refresh: SwiftUI may cancel the gesture's task mid-load; that is not an error to show.
    @Test func cancelledReloadKeepsTheScreenWithoutAnAlert() async {
        let data = CarePreviewData.make()
        let model = BabyCareViewModel(provider: CancellingProvider(database: data), initialData: data)
        #expect(!(await model.send(.load)))
        #expect(model.state.phase == .ready && model.state.error == nil && !model.state.isRefreshing)
        #expect(model.activities == data.selectedBaby?.activities)
    }
}

private actor CancellingProvider: CareDataProvider {
    let database: CareDatabase
    init(database: CareDatabase) { self.database = database }
    func load() throws -> CareDatabase { throw CancellationError() }
    func apply(_ mutation: CareDataMutation) throws -> CareDatabase { database }
}

private actor MemoryCloudCache: CareCloudCache {
    private var state = CloudCacheState()
    func read() -> CloudCacheState { state }
    func write(_ value: CloudCacheState) { state = value }
}

/// A family on the server with a revision; counts full reads.
private actor RevisionRemote: CareCloudRemote {
    private var snapshot = CloudSnapshot()
    private var applyError: CloudError?
    private(set) var fetches = 0
    func set(_ value: CloudSnapshot) { snapshot = value }
    func setApplyError(_ error: CloudError?) { applyError = error }
    func invalidate() {}
    func revision() throws -> Int? {
        if applyError == .accessDenied { throw CloudError.accessDenied }
        return snapshot.revision
    }
    func fetch(selected: UUID?) throws -> CloudSnapshot {
        if applyError == .accessDenied { throw CloudError.accessDenied }
        fetches += 1
        return snapshot
    }
    func apply(_ envelope: CloudEnvelope) throws -> CloudReceipt {
        if let applyError { throw applyError }
        snapshot.revision += 1
        return CloudReceipt(operation_id: envelope.p_operation_id, revision: snapshot.revision,
            records: envelope.p_changes.map { .init(entity: $0.entity, id: $0.id, version: $0.expected_version + 1) })
    }
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) -> CloudMediaSyncResult {
        CloudMediaSyncResult(assets: [], revision: old.revision, records: [])
    }
    func deleteBaby(_ id: UUID) {}
}
