import Foundation
import Testing
import Supabase
@testable import BabyCare

private actor FakeConsentRemote: ConsentRemote {
    var current: ConsentStatus = .init(required: .bundled, accepted: nil, valid: false)
    var fail = false
    var hold = false
    var continuation: CheckedContinuation<Void, Never>?
    private(set) var submissions = 0
    func configure(fail: Bool = false, hold: Bool = false) { self.fail = fail; self.hold = hold }
    func status() -> ConsentStatus { current }
    func setStatus(_ status: ConsentStatus) { current = status }
    func release() { continuation?.resume(); continuation = nil }
    func accept(versions: ConsentVersions) async throws -> ConsentStatus {
        submissions += 1
        if hold { await withCheckedContinuation { continuation = $0 } }
        if fail { throw URLError(.notConnectedToInternet) }
        let stamp = "2026-09-18T12:00:00Z"
        current = .init(required: versions, accepted: .init(terms_version: versions.terms_version,
            privacy_version: versions.privacy_version, health_version: versions.health_version,
            terms_accepted_at: stamp, privacy_accepted_at: stamp, health_accepted_at: stamp,
            representative_confirmed: true, representative_confirmed_at: stamp, created_at: stamp), valid: true)
        return current
    }
}

@MainActor struct ConsentTests {
    @Test func threeIndependentConfirmationsRequired() async {
        let model = ConsentViewModel(remote: FakeConsentRemote())
        #expect(!model.terms && !model.health && !model.representative && !model.canSubmit)
        #expect(await model.refresh() == false)
        for mask in 0..<8 {
            model.terms = mask & 1 != 0; model.health = mask & 2 != 0; model.representative = mask & 4 != 0
            #expect(model.canSubmit == (mask == 7))
        }
    }
    @Test func successfulSubmissionOpensGateOnlyAfterResponse() async {
        let remote = FakeConsentRemote()
        let subject = ConsentViewModel(remote: remote)
        _ = await subject.refresh()
        subject.terms = true; subject.health = true; subject.representative = true
        await remote.configure(hold: true)
        let first = Task { await subject.submit() }
        while await remote.submissions == 0 { await Task.yield() }
        #expect(subject.busy && !subject.canSubmit && subject.status?.isCurrent == false)
        #expect(await subject.submit() == false)
        #expect(await remote.submissions == 1)
        await remote.release()
        #expect(await first.value)
        #expect(subject.status?.isCurrent == true)
        #expect(!subject.canSubmit)
    }
    @Test func failedAPICannotCompleteConsentAndCanRetry() async {
        let remote = FakeConsentRemote()
        let subject = ConsentViewModel(remote: remote)
        _ = await subject.refresh()
        subject.terms = true; subject.health = true; subject.representative = true
        await remote.configure(fail: true)
        #expect(await subject.submit() == false)
        #expect(subject.status?.isCurrent == false && subject.error != nil && subject.canSubmit)
        await remote.configure()
        #expect(await subject.submit())
    }
    @Test func missingOutdatedOrUnknownDocumentsKeepGateClosed() async throws {
        let remote = FakeConsentRemote(), subject = ConsentViewModel(remote: FakeConsentRemote())
        #expect(await subject.refresh() == false)
        let valid = try await remote.accept(versions: .bundled)
        let newer = ConsentVersions(terms_version: "2.0", privacy_version: "1.0", health_version: "1.0")
        await remote.setStatus(.init(required: newer, accepted: valid.accepted, valid: false))
        let outdated = ConsentViewModel(remote: remote)
        #expect(await outdated.refresh() == false)
        outdated.terms = true; outdated.health = true; outdated.representative = true
        #expect(!outdated.canSubmit && outdated.error != nil)
    }
    @Test func sessionResetDiscardsLateAcceptance() async {
        let remote = FakeConsentRemote()
        let model = ConsentViewModel(remote: remote)
        _ = await model.refresh()
        model.terms = true; model.health = true; model.representative = true
        await remote.configure(hold: true)
        let pending = Task { await model.submit() }
        while await remote.submissions == 0 { await Task.yield() }
        model.reset()
        await remote.release()
        #expect(await pending.value == false)
        #expect(model.status == nil && !model.terms && !model.busy)
    }

    @Test(arguments: [false, true])
    func restoredSessionRequiresConsentBeforeChildProfile(outdated: Bool) async throws {
        let remote = FakeConsentRemote()
        if outdated {
            let old = try await remote.accept(versions: .init(terms_version: "old", privacy_version: "old", health_version: "old"))
            await remote.setStatus(.init(required: .bundled, accepted: old.accepted, valid: false))
        }
        let suite = "ConsentTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("device", forKey: "care.mode")
        let session = SessionViewModel(consentRemote: remote, defaults: defaults,
            makeLocalViewModel: { BabyCareViewModel(provider: InMemoryCareDataProvider()) })
        let (events, continuation) = AsyncStream<(event: AuthChangeEvent, session: Session?)>.makeStream()
        defer { continuation.finish() }
        session.start(events: events)
        let user = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        createdAt: .now, updatedAt: .now)
        continuation.yield((.initialSession, Session(accessToken: "synthetic", tokenType: "bearer", expiresIn: 3600,
            expiresAt: Date.now.timeIntervalSince1970 + 3600, refreshToken: "synthetic", user: user)))
        for _ in 0..<1000 {
            if session.phase != .starting { break }
            await Task.yield()
        }
        #expect(session.phase == .consent && session.viewModel == nil)
        session.consent.terms = true; session.consent.health = true; session.consent.representative = true
        await remote.configure(fail: true)
        await session.completeConsent()
        #expect(session.phase == .consent && session.viewModel == nil)
        await remote.configure()
        await session.completeConsent()
        #expect(session.phase == .content)
        let model = try #require(session.viewModel)
        _ = await model.send(.load)
        #expect(model.babies.isEmpty) // ContentView presents Create Child Profile for the empty store.
        await remote.setStatus(.init(required: .bundled, accepted: nil, valid: false))
        await session.checkConsent()
        #expect(session.phase == .consent && session.viewModel == nil)
    }
}
