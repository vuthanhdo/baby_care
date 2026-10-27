import Foundation
import Supabase

/// Where a suggestion is on the feature board (migration 0014). The developer moves it in the dashboard.
nonisolated enum CareFeatureStatus: String, Decodable, Sendable {
    case pending, open, planned, done, declined
    var votable: Bool { self == .open || self == .planned }
    var isPublished: Bool { self == .open || self == .planned || self == .done }
    var badge: String? {
        switch self {
        case .pending: L10n.text("Chờ duyệt")
        case .open: nil
        case .planned: L10n.text("Đã lên kế hoạch")
        case .done: L10n.text("Đã có trong app")
        case .declined: L10n.text("Chưa thực hiện")
        }
    }
}

nonisolated struct CareFeatureRequest: Decodable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var details: String
    var status: CareFeatureStatus
    var votes: Int
    /// The signed-in parent's vote; nobody sees who else voted or who wrote it.
    var voted: Bool
    var mine: Bool
}

nonisolated struct CareFeatureVote: Decodable, Equatable, Sendable {
    var voted: Bool
    var votes: Int
}

nonisolated protocol CareFeatureRemote: Sendable {
    func board() async throws -> [CareFeatureRequest]
    func submit(id: UUID, title: String, details: String) async throws
    func toggleVote(id: UUID) async throws -> CareFeatureVote
    func report(id: UUID) async throws
}

nonisolated struct SupabaseFeatureRemote: CareFeatureRemote {
    let client: SupabaseClient
    private struct Request: Encodable, Sendable { let p_request_id: UUID }

    func board() async throws -> [CareFeatureRequest] {
        do { return try await client.rpc("babycare_feature_board").execute().value }
        catch { throw CloudError.normalize(error) }
    }
    func submit(id: UUID, title: String, details: String) async throws {
        struct Params: Encodable, Sendable { let p_id: UUID; let p_title: String; let p_details: String }
        do { _ = try await client.rpc("babycare_submit_feature", params: Params(p_id: id, p_title: title, p_details: details)).execute() }
        catch { throw CloudError.normalize(error) }
    }
    func toggleVote(id: UUID) async throws -> CareFeatureVote {
        do { return try await client.rpc("babycare_toggle_feature_vote", params: Request(p_request_id: id)).execute().value }
        catch { throw CloudError.normalize(error) }
    }
    func report(id: UUID) async throws {
        do { _ = try await client.rpc("babycare_report_feature", params: Request(p_request_id: id)).execute() }
        catch { throw CloudError.normalize(error) }
    }
}
