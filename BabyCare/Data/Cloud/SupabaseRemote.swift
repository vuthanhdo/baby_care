import Foundation
import Supabase

nonisolated enum CloudConfiguration {
    static let url = URL(string: "https://cxlqvuqloaokzmaewvdy.supabase.co")!
    // Public client key. Authorization is enforced by session JWT + database RLS.
    static let publishableKey = "sb_publishable_wiLbsz0rj_tMAiGNv5a6pA_G-noEQ7n"
    static func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: publishableKey, options: .init(auth: .init(
            storage: KeychainLocalStorage(service: "com.vuthanhdo.BabyCare.auth"),
            storageKey: "babycare.session", emitLocalSessionAsInitialSession: true)))
    }
}

nonisolated enum CloudError: Error, LocalizedError, Sendable, Equatable {
    case offline, accessDenied, signedOut, conflict, uncertain, busy
    var errorDescription: String? {
        switch self {
        case .offline: L10n.text("Không kết nối được cloud. Chỉ có thể xem bản lưu trên máy; hãy tải lại khi có mạng.")
        case .accessDenied: L10n.text("Bạn không còn quyền truy cập gia đình này. Hãy chọn lại gia đình hoặc đăng nhập lại.")
        case .signedOut: L10n.text("Phiên đăng nhập đã kết thúc. Hãy đăng nhập lại.")
        case .conflict: L10n.text("Dữ liệu cloud đã thay đổi. Hãy tải lại trước khi lưu tiếp.")
        case .uncertain: L10n.text("Chưa xác nhận được kết quả lưu. Hãy tải lại để đối soát yêu cầu cũ trước khi lưu tiếp.")
        case .busy: L10n.text("Đang xử lý dữ liệu. Hãy chờ thao tác hiện tại hoàn tất.")
        }
    }
    static func normalize(_ error: Error) -> Error {
        if let e = error as? PostgrestError {
            if e.code == "P0001", e.message == "Baby limit reached" { return CareDataError.invalidInput(L10n.text("Bạn chỉ có thể tạo tối đa 4 hồ sơ bé.")) }
            if e.code == "40001" || e.code == "23505" { return CloudError.conflict }
            if e.code == "42501" || e.code == "PGRST301" || e.code == "PGRST302" { return CloudError.accessDenied }
            return CareDataError.invalidInput(L10n.text("Cloud từ chối dữ liệu ({0}). Hãy kiểm tra thông tin rồi thử lại.", "\(e.code ?? "unknown")"))
        }
        if error is AuthError { return CloudError.signedOut }
        if let e = error as? StorageError {
            if e.statusCode == "401" || e.statusCode == "403" { return CloudError.accessDenied }
            if e.statusCode == nil || e.statusCode?.hasPrefix("5") == true { return CloudError.offline }
            return CareDataError.invalidInput(L10n.text("Không thể xử lý ảnh trên cloud ({0}).", "\(e.message)"))
        }
        if let e = error as? URLError, e.code != .cancelled { return CloudError.offline }
        return error
    }
}

nonisolated struct CloudFamily: Codable, Sendable, Identifiable {
    var id: UUID; var name: String; var revision: Int
}
nonisolated protocol CareCloudRemote: Sendable {
    func fetch(selected: UUID?) async throws -> CloudSnapshot
    func apply(_ envelope: CloudEnvelope) async throws -> CloudReceipt
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) async throws -> CloudMediaSyncResult
    func invalidate() async
}

actor CloudSessionLease {
    private var active = true
    func check() throws { guard active else { throw CloudError.signedOut }; try Task.checkCancellation() }
    func invalidate() { active = false }
}

/// Each provider receives a client whose token callback is bound to one account.
/// Even an in-flight request can never pick up a different account's new session.
actor SupabaseRemote: CareCloudRemote {
    private let client: SupabaseClient
    private let lease: CloudSessionLease
    private let familyID: UUID
    private let network: URLSession
    init(authClient: SupabaseClient, userID: UUID, familyID: UUID) {
        let lease = CloudSessionLease()
        self.lease = lease; self.familyID = familyID
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        network = URLSession(configuration: configuration)
        client = SupabaseClient(supabaseURL: CloudConfiguration.url, supabaseKey: CloudConfiguration.publishableKey,
            options: .init(auth: .init(autoRefreshToken: false, accessToken: {
                try await lease.check()
                let session = try await authClient.auth.session
                guard session.user.id == userID else { throw CloudError.signedOut }
                try await lease.check()
                return session.accessToken
            }), global: .init(session: network)))
    }
    deinit { network.invalidateAndCancel() }
    func invalidate() async { await lease.invalidate(); network.invalidateAndCancel() }
    func apply(_ envelope: CloudEnvelope) async throws -> CloudReceipt {
        do {
            try await lease.check()
            guard envelope.p_family_id == familyID else { throw CloudError.accessDenied }
            let receipt: CloudReceipt = try await client.rpc("babycare_apply", params: envelope).execute().value
            try await lease.check()
            return receipt
        } catch { throw CloudError.normalize(error) }
    }
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) async throws -> CloudMediaSyncResult {
        do {
            try await lease.check()
            let desired = try CloudMediaPlan.desired(in: next, familyID: familyID,
                operationID: operationID, existing: old.mediaAssets ?? [])
            let oldAssets = old.mediaAssets ?? []
            var assets: [CloudMediaAsset] = []
            var records: [CloudReceipt.Record] = []
            var revision = old.revision

            for upload in desired {
                try await lease.check()
                if let existing = oldAssets.first(where: { $0.id == upload.asset.id }), existing.status == "ready" {
                    assets.append(existing)
                    continue
                }
                var asset = upload.asset
                if let existing = oldAssets.first(where: { $0.id == asset.id }) {
                    asset = existing
                } else {
                    let data: CloudRow = [
                        "activity_id": asset.activityID.map(CloudValue.id) ?? .null,
                        "purpose": .string(asset.purpose.rawValue), "mime_type": .string(asset.mimeType),
                        "byte_count": .number(Double(asset.byteCount)), "status": .string("pending")
                    ]
                    let receipt = try await apply(CloudEnvelope(
                        p_operation_id: CloudMediaPlan.operationID(assetID: asset.id, stage: "create"),
                        p_family_id: familyID,
                        p_changes: [CloudChange(entity: "media_assets", id: asset.id, baby_id: asset.babyID,
                            expected_version: 0, data: data)]))
                    guard let record = receipt.records.first else { throw CareDataError.corruptData }
                    asset.version = record.version; revision = receipt.revision; records += receipt.records
                }

                let bucket = client.storage.from("babycare-media")
                do {
                    // An earlier upload may have succeeded before its response was lost.
                    let stored = try await bucket.download(path: asset.objectPath)
                    guard stored == upload.data else { throw CloudError.conflict }
                } catch let error as StorageError where error.statusCode == "404"
                    || error.error == "NoSuchKey" || error.message.lowercased() == "object not found" {
                    _ = try await bucket.upload(asset.objectPath, data: upload.data,
                        options: FileOptions(cacheControl: "31536000", contentType: asset.mimeType, upsert: false))
                }
                try await lease.check()
                let ready = try await apply(CloudEnvelope(
                    p_operation_id: CloudMediaPlan.operationID(assetID: asset.id, stage: "ready"),
                    p_family_id: familyID,
                    p_changes: [CloudChange(entity: "media_assets", id: asset.id, baby_id: asset.babyID,
                        expected_version: asset.version, data: ["status": .string("ready")])]))
                guard let record = ready.records.first else { throw CareDataError.corruptData }
                asset.version = record.version; asset.status = "ready"
                revision = ready.revision; records += ready.records; assets.append(asset)
            }

            let desiredIDs = Set(desired.map(\.asset.id))
            for asset in oldAssets where !desiredIDs.contains(asset.id) {
                let babyIsLive = next.babies.contains { $0.profile.id == asset.babyID }
                let activityIsLive = asset.activityID.map { id in
                    next.babies.contains { $0.activities.contains { $0.id == id } }
                } ?? true
                guard babyIsLive, activityIsLive else { continue }
                let receipt = try await apply(CloudEnvelope(
                    p_operation_id: CloudMediaPlan.operationID(assetID: asset.id, stage: "delete-\(operationID)-\(asset.version)"),
                    p_family_id: familyID,
                    p_changes: [CloudChange(entity: "media_assets", id: asset.id, baby_id: asset.babyID,
                        expected_version: asset.version, data: [:], deleted: true)]))
                revision = receipt.revision; records += receipt.records
            }
            return CloudMediaSyncResult(assets: assets, revision: revision, records: records)
        } catch { throw CloudError.normalize(error) }
    }
    func fetch(selected: UUID?) async throws -> CloudSnapshot {
        struct Page: Decodable { var revision: Int; var rows: [CloudRow]; var next_after_id: UUID? }
        struct Params: Encodable { var p_family_id: UUID; var p_entity: String; var p_at_revision: Int; var p_after_id: UUID?; var p_limit = 200 }
        do {
            for attempt in 0..<3 {
                do {
                    try await lease.check()
                    let families: [CloudFamily] = try await client.from("families").select().eq("id", value: familyID).execute().value
                    guard let family = families.first else { throw CloudError.accessDenied }
                    var tables: [String: [CloudRow]] = [:]
                    for entity in CloudMapping.entities {
                        var cursor: UUID?
                        repeat {
                            try await lease.check()
                            let page: Page = try await client.rpc("babycare_read_page", params: Params(p_family_id: familyID, p_entity: entity, p_at_revision: family.revision, p_after_id: cursor)).execute().value
                            guard page.revision == family.revision, page.next_after_id == nil || page.next_after_id != cursor else { throw CareDataError.corruptData }
                            tables[entity, default: []].append(contentsOf: page.rows)
                            cursor = page.next_after_id
                        } while cursor != nil
                    }
                    try await lease.check()
                    var snapshot = try CloudMapping.decode(tables, revision: family.revision, selected: selected)
                    var hydrated: [CloudMediaAsset] = []
                    for var asset in (snapshot.mediaAssets ?? []).sorted(by: { $0.id.uuidString < $1.id.uuidString }) where asset.status == "ready" {
                        try await lease.check()
                        guard let babyIndex = snapshot.database.babies.firstIndex(where: { $0.profile.id == asset.babyID }),
                              asset.activityID == nil || snapshot.database.babies[babyIndex].activities.contains(where: { $0.id == asset.activityID }) else { continue }
                        let data = try await client.storage.from("babycare-media").download(path: asset.objectPath)
                        guard data.count == asset.byteCount else { throw CareDataError.corruptData }
                        asset.contentHash = CloudMediaPlan.contentHash(data)
                        if asset.purpose == .avatar {
                            asset.position = 0
                            snapshot.database.babies[babyIndex].profile.avatarData = data
                        } else if let activityID = asset.activityID,
                                  let activityIndex = snapshot.database.babies[babyIndex].activities.firstIndex(where: { $0.id == activityID }) {
                            asset.position = snapshot.database.babies[babyIndex].activities[activityIndex].attachments.count
                            snapshot.database.babies[babyIndex].activities[activityIndex].attachments.append(data)
                        }
                        hydrated.append(asset)
                    }
                    snapshot.mediaAssets = hydrated
                    return snapshot
                } catch let error as PostgrestError where error.code == "40001" && attempt < 2 { continue }
            }
            throw CloudError.conflict
        } catch { throw CloudError.normalize(error) }
    }
}
