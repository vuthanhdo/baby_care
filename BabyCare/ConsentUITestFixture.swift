#if DEBUG
import Foundation
import Supabase

/// Synthetic auth/consent transport only. Exercises the real session routing and UI,
/// with an in-memory child store; never contacts Supabase or loads personal data.
@MainActor enum ConsentUITestFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing-consent") }
    static func makeSession() -> SessionViewModel {
        let defaults = UserDefaults(suiteName: "BabyCare.ConsentUITests")!
        defaults.removePersistentDomain(forName: "BabyCare.ConsentUITests")
        defaults.set("device", forKey: "care.mode")
        return SessionViewModel(consentRemote: Transport(), defaults: defaults,
            makeLocalViewModel: { BabyCareViewModel(provider: InMemoryCareDataProvider()) })
    }
    static func events() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { stream in
            let user = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: .now, updatedAt: .now)
            stream.yield((.initialSession, Session(accessToken: "synthetic", tokenType: "bearer", expiresIn: 3600,
                expiresAt: Date.now.timeIntervalSince1970 + 3600, refreshToken: "synthetic", user: user)))
            stream.finish()
        }
    }
    private actor Transport: ConsentRemote {
        var current = ConsentStatus(required: .bundled, accepted: nil, valid: false)
        var failOnce = ProcessInfo.processInfo.arguments.contains("-ui-testing-consent-failure")
        func status() -> ConsentStatus { current }
        func accept(versions: ConsentVersions) async throws -> ConsentStatus {
            try await Task.sleep(for: .milliseconds(250))
            if failOnce { failOnce = false; throw URLError(.notConnectedToInternet) }
            let stamp = "2026-09-18T12:00:00Z"
            current = ConsentStatus(required: versions, accepted: ConsentRecord(
                terms_version: versions.terms_version, privacy_version: versions.privacy_version,
                health_version: versions.health_version, terms_accepted_at: stamp, privacy_accepted_at: stamp,
                health_accepted_at: stamp, representative_confirmed: true, representative_confirmed_at: stamp,
                created_at: stamp), valid: true)
            return current
        }
    }
}
#endif
