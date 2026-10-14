import Foundation
import Observation
import Supabase

nonisolated struct ConsentVersions: Codable, Equatable, Sendable {
    let terms_version: String
    let privacy_version: String
    let health_version: String
    // Versions of documents bundled in this release, not a replacement for server requirements.
    static let bundled = ConsentVersions(terms_version: "1.0", privacy_version: "1.0", health_version: "1.0")
}

nonisolated struct ConsentRecord: Codable, Equatable, Sendable {
    let terms_version: String
    let privacy_version: String
    let health_version: String
    let terms_accepted_at: String
    let privacy_accepted_at: String
    let health_accepted_at: String
    let representative_confirmed: Bool
    let representative_confirmed_at: String
    let created_at: String
}

nonisolated struct ConsentStatus: Codable, Equatable, Sendable {
    let required: ConsentVersions
    let accepted: ConsentRecord?
    let valid: Bool
    var isCurrent: Bool {
        guard valid, let accepted else { return false }
        return accepted.representative_confirmed && accepted.terms_version == required.terms_version
            && accepted.privacy_version == required.privacy_version && accepted.health_version == required.health_version
    }
}

nonisolated protocol ConsentRemote: Sendable {
    func status() async throws -> ConsentStatus
    func accept(versions: ConsentVersions) async throws -> ConsentStatus
}

nonisolated struct SupabaseConsentRemote: ConsentRemote {
    let client: SupabaseClient
    func status() async throws -> ConsentStatus {
        try await client.rpc("babycare_consent_status").execute().value
    }
    func accept(versions: ConsentVersions) async throws -> ConsentStatus {
        struct Params: Encodable {
            let p_terms_version: String, p_privacy_version: String, p_health_version: String
            let p_terms_accepted = true, p_health_accepted = true, p_representative_confirmed = true
        }
        return try await client.rpc("babycare_accept_consent", params: Params(
            p_terms_version: versions.terms_version, p_privacy_version: versions.privacy_version,
            p_health_version: versions.health_version)).execute().value
    }
}

@MainActor @Observable final class ConsentViewModel {
    var terms = false
    var health = false
    var representative = false
    private(set) var status: ConsentStatus?
    private(set) var busy = false
    private(set) var error: String?
    /// Account the local record belongs to; the session sets it after sign-in.
    @ObservationIgnored var userKey: String?
    @ObservationIgnored private let remote: any ConsentRemote
    @ObservationIgnored private let store: UserDefaults
    @ObservationIgnored private var generation = 0
    init(remote: any ConsentRemote, store: UserDefaults = .standard) { self.remote = remote; self.store = store }

    /// Three explicit confirmations are enough; there is one terms & conditions document, no version gate.
    var canSubmit: Bool { terms && health && representative && !busy && !isAccepted }
    var acceptedLocallyAt: Date? {
        get { userKey.flatMap { store.object(forKey: Self.key($0)) as? Date } }
        set { guard let userKey else { return }; store.set(newValue, forKey: Self.key(userKey)) }
    }
    /// The server's answer wins whenever it can be reached; otherwise the local record applies.
    var isAccepted: Bool { status.map(\.isCurrent) ?? (acceptedLocallyAt != nil) }
    private static func key(_ user: String) -> String { "care.consent.accepted.\(user)" }

    func reset() {
        generation += 1; busy = false; status = nil; error = nil; userKey = nil
        terms = false; health = false; representative = false
    }
    func refresh() async -> Bool {
        guard !busy else { return false }
        let ticket = generation
        busy = true; error = nil
        defer { if ticket == generation { busy = false } }
        do {
            var result = try await remote.status()
            guard ticket == generation else { return false }
            // Accepted offline earlier: record it on the server now instead of asking again.
            if !result.isCurrent, acceptedLocallyAt != nil, let synced = try? await remote.accept(versions: result.required) {
                guard ticket == generation else { return false }
                result = synced
            }
            status = result
        } catch {
            guard ticket == generation else { return false }
            status = nil // Offline or the consent RPC is not deployed: the local record decides.
        }
        return isAccepted
    }
    func submit() async -> Bool {
        guard canSubmit else { return false }
        let ticket = generation
        busy = true; error = nil
        defer { if ticket == generation { busy = false } }
        acceptedLocallyAt = Date()
        do {
            let result = try await remote.accept(versions: status?.required ?? .bundled)
            guard ticket == generation else { return false }
            status = result
        } catch {
            guard ticket == generation else { return false }
            status = nil // Keep the local record; refresh() retries the server later.
        }
        return isAccepted
    }
}
