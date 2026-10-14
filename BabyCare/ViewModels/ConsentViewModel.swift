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
    @ObservationIgnored private let remote: any ConsentRemote
    @ObservationIgnored private var generation = 0
    init(remote: any ConsentRemote) { self.remote = remote }
    var canSubmit: Bool {
        terms && health && representative && !busy && status?.required == .bundled && status?.isCurrent != true
    }
    func reset() {
        generation += 1; busy = false; status = nil; error = nil
        terms = false; health = false; representative = false
    }
    func refresh() async -> Bool {
        guard !busy else { return false }
        let ticket = generation
        busy = true; error = nil
        defer { if ticket == generation { busy = false } }
        do {
            let result = try await remote.status()
            guard ticket == generation else { return false }
            status = result
            if result.required != .bundled { error = L10n.text("Vui lòng cập nhật BabyCare để xem và đồng ý với tài liệu mới nhất.") }
            return result.isCurrent
        } catch {
            guard ticket == generation else { return false }
            self.error = L10n.text("Chưa kiểm tra được sự đồng ý. Hãy kiểm tra kết nối và thử lại.")
            return false
        }
    }
    func submit() async -> Bool {
        guard canSubmit, let versions = status?.required else { return false }
        let ticket = generation
        busy = true; error = nil
        defer { if ticket == generation { busy = false } }
        do {
            let result = try await remote.accept(versions: versions)
            guard ticket == generation else { return false }
            status = result
            guard result.isCurrent else { throw CloudError.consentRequired }
            return true
        } catch {
            guard ticket == generation else { return false }
            self.error = L10n.text("Chưa ghi nhận được sự đồng ý. Vui lòng thử lại.")
            // Fetch changed requirements without accepting them or looping automatically.
            if CloudError.normalize(error) as? CloudError == .consentRequired {
                status = nil; terms = false; health = false; representative = false
            }
            return false
        }
    }
}
