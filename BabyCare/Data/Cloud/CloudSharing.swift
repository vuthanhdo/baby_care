import Foundation
import Supabase

/// What a member may do in a family; the server enforces the same rules (migration 0012).
nonisolated enum CareFamilyRole: String, Codable, Sendable, CaseIterable {
    case owner, caregiver, viewer
    var canWrite: Bool { self != .viewer }
    var title: String {
        switch self {
        case .owner: L10n.text("Chủ gia đình")
        case .caregiver: L10n.text("Cùng chăm sóc")
        case .viewer: L10n.text("Chỉ xem")
        }
    }
    var summary: String {
        switch self {
        case .owner: L10n.text("Mời, gỡ thành viên và xóa hồ sơ bé")
        case .caregiver: L10n.text("Xem và ghi cho mọi bé trong gia đình")
        case .viewer: L10n.text("Chỉ xem, không ghi được")
        }
    }
}

/// Postgres JSON timestamps carry microseconds and an offset.
nonisolated enum CloudTimestamp {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

nonisolated struct CloudFamilySummary: Decodable, Sendable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var revision: Int
    var role: CareFamilyRole
    var createdBy: UUID
    var ownerEmail: String
    var memberCount: Int
    enum CodingKeys: String, CodingKey {
        case id, name, revision, role, createdBy = "created_by", ownerEmail = "owner_email", memberCount = "member_count"
    }
}

nonisolated struct CloudFamilyMember: Decodable, Sendable, Identifiable, Equatable {
    var userID: UUID
    var email: String
    var role: CareFamilyRole
    var joinedAt: Date
    var id: UUID { userID }
    enum CodingKeys: String, CodingKey { case userID = "user_id", email, role, joinedAt = "joined_at" }
    init(userID: UUID, email: String, role: CareFamilyRole, joinedAt: Date) {
        self.userID = userID; self.email = email; self.role = role; self.joinedAt = joinedAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UUID.self, forKey: .userID); email = try c.decode(String.self, forKey: .email)
        role = try c.decode(CareFamilyRole.self, forKey: .role)
        guard let joined = CloudTimestamp.parse(try c.decode(String.self, forKey: .joinedAt)) else {
            throw DecodingError.dataCorruptedError(forKey: .joinedAt, in: c, debugDescription: "timestamp")
        }
        joinedAt = joined
    }
}

nonisolated struct CloudFamilyInvite: Decodable, Sendable, Identifiable, Equatable {
    var id: UUID
    var role: CareFamilyRole
    var expiresAt: Date
    enum CodingKeys: String, CodingKey { case id, role, expiresAt = "expires_at" }
    init(id: UUID, role: CareFamilyRole, expiresAt: Date) { self.id = id; self.role = role; self.expiresAt = expiresAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); role = try c.decode(CareFamilyRole.self, forKey: .role)
        guard let expires = CloudTimestamp.parse(try c.decode(String.self, forKey: .expiresAt)) else {
            throw DecodingError.dataCorruptedError(forKey: .expiresAt, in: c, debugDescription: "timestamp")
        }
        expiresAt = expires
    }
}

nonisolated struct CloudFamilySharing: Decodable, Sendable, Equatable {
    var role: CareFamilyRole
    var createdBy: UUID
    var members: [CloudFamilyMember]
    var invites: [CloudFamilyInvite]
    enum CodingKeys: String, CodingKey { case role, createdBy = "created_by", members, invites }
}

/// A new invite. The code is shown once; the server keeps only its hash.
nonisolated struct CloudCreatedInvite: Decodable, Sendable, Equatable {
    var invite: CloudFamilyInvite
    var code: String
    enum CodingKeys: String, CodingKey { case code }
    init(invite: CloudFamilyInvite, code: String) { self.invite = invite; self.code = code }
    init(from decoder: Decoder) throws {
        invite = try CloudFamilyInvite(from: decoder)
        code = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .code)
    }
}

nonisolated struct CloudInviteAnswer: Decodable, Sendable, Equatable {
    enum Status: String, Decodable, Sendable { case joined, alreadyMember = "already_member", invalid, expired, revoked, used, familyFull = "family_full", rateLimited = "rate_limited" }
    var status: Status
    var familyID: UUID?
    var ownerEmail: String?
    var role: CareFamilyRole?
    enum CodingKeys: String, CodingKey { case status, familyID = "family_id", ownerEmail = "owner_email", role }

    /// Why the code did not work, for the parent who typed it.
    var problem: String? {
        switch status {
        case .joined, .alreadyMember: nil
        case .invalid: L10n.text("Mã mời không đúng. Kiểm tra lại 8 ký tự.")
        case .expired: L10n.text("Mã mời đã hết hạn. Nhờ người mời tạo mã mới.")
        case .revoked: L10n.text("Mã mời đã bị hủy. Nhờ người mời tạo mã mới.")
        case .used: L10n.text("Mã mời này đã được dùng. Mỗi mã chỉ dùng một lần.")
        case .familyFull: L10n.text("Gia đình này đã đủ 6 thành viên.")
        case .rateLimited: L10n.text("Bạn đã nhập sai quá nhiều lần. Hãy thử lại sau 1 giờ.")
        }
    }
}

nonisolated protocol CareSharingRemote: Sendable {
    /// Nil when the server does not have migration 0012 yet.
    func myFamilies() async throws -> [CloudFamilySummary]?
    func sharing(familyID: UUID) async throws -> CloudFamilySharing
    func createInvite(familyID: UUID, role: CareFamilyRole) async throws -> CloudCreatedInvite
    func acceptInvite(code: String) async throws -> CloudInviteAnswer
    func revokeInvite(id: UUID) async throws
    func setRole(familyID: UUID, userID: UUID, role: CareFamilyRole) async throws
    func removeMember(familyID: UUID, userID: UUID) async throws
    func leaveFamily(familyID: UUID) async throws
}

nonisolated struct SupabaseSharingRemote: CareSharingRemote {
    let client: SupabaseClient

    private func call<T: Decodable & Sendable>(_ function: String, _ params: some Encodable & Sendable) async throws -> T {
        do { return try await client.rpc(function, params: params).execute().value }
        catch { throw CloudError.normalize(error) }
    }
    private func run(_ function: String, _ params: some Encodable & Sendable) async throws {
        do { _ = try await client.rpc(function, params: params).execute() }
        catch { throw CloudError.normalize(error) }
    }
    private struct Family: Encodable, Sendable { let p_family_id: UUID }
    private struct Member: Encodable, Sendable { let p_family_id: UUID; let p_user_id: UUID }

    func myFamilies() async throws -> [CloudFamilySummary]? {
        do { return try await client.rpc("babycare_my_families").execute().value }
        catch let error as PostgrestError where error.code == "PGRST202" { return nil }
        catch { throw CloudError.normalize(error) }
    }
    func sharing(familyID: UUID) async throws -> CloudFamilySharing {
        try await call("babycare_family_sharing", Family(p_family_id: familyID))
    }
    func createInvite(familyID: UUID, role: CareFamilyRole) async throws -> CloudCreatedInvite {
        struct Params: Encodable, Sendable { let p_family_id: UUID; let p_role: String }
        return try await call("babycare_create_invite", Params(p_family_id: familyID, p_role: role.rawValue))
    }
    func acceptInvite(code: String) async throws -> CloudInviteAnswer {
        struct Params: Encodable, Sendable { let p_code: String }
        return try await call("babycare_accept_invite", Params(p_code: code))
    }
    func revokeInvite(id: UUID) async throws {
        struct Params: Encodable, Sendable { let p_invite_id: UUID }
        try await run("babycare_revoke_invite", Params(p_invite_id: id))
    }
    func setRole(familyID: UUID, userID: UUID, role: CareFamilyRole) async throws {
        struct Params: Encodable, Sendable { let p_family_id: UUID; let p_user_id: UUID; let p_role: String }
        try await run("babycare_set_member_role", Params(p_family_id: familyID, p_user_id: userID, p_role: role.rawValue))
    }
    func removeMember(familyID: UUID, userID: UUID) async throws {
        try await run("babycare_remove_member", Member(p_family_id: familyID, p_user_id: userID))
    }
    func leaveFamily(familyID: UUID) async throws {
        try await run("babycare_leave_family", Family(p_family_id: familyID))
    }
}

/// Invite codes as people type them: eight letters and digits, case and separators ignored.
nonisolated enum CareInviteCode {
    static let length = 8
    static func normalize(_ text: String) -> String {
        String(text.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII }.map(Character.init))
    }
    static func isComplete(_ text: String) -> Bool { normalize(text).count == length }
    /// "ABCD EFGH": easier to read aloud and to copy by eye.
    static func display(_ code: String) -> String {
        let clean = normalize(code)
        guard clean.count == length else { return clean }
        return "\(clean.prefix(4)) \(clean.suffix(4))"
    }
    /// `babycare://invite?code=ABCDEFGH`, opened from the shared message.
    static func link(_ code: String) -> URL {
        var components = URLComponents()
        components.scheme = "babycare"; components.host = "invite"
        components.queryItems = [URLQueryItem(name: "code", value: normalize(code))]
        return components.url!
    }
    static func code(from url: URL) -> String? {
        guard url.scheme == "babycare", url.host == "invite",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
              isComplete(value) else { return nil }
        return normalize(value)
    }
    /// The message sent with ShareLink: how to get the app and how to join.
    static func message(code: String, role: CareFamilyRole) -> String {
        L10n.text("Mời bạn cùng chăm bé trên Bé Khỏe ({0}).\n1. Tải app: {1}\n2. Đăng nhập, vào Cài đặt → Gia đình & chia sẻ → Nhập mã mời: {2}\nHoặc mở liên kết: {3}\nMã dùng một lần, hết hạn sau 48 giờ.",
                  role.title.lowercased(), CareAppStore.link(campaign: "invite").absoluteString, display(code), link(code).absoluteString)
    }
}
