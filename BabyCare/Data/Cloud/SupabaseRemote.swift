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
    case offline, accessDenied, signedOut, conflict, uncertain, busy, vaccinationsUnavailable, consentRequired
    /// The server refuses the data itself (a check, a type or a missing field). Retrying sends the same request
    /// and gets the same answer, so the outbox drops such a write instead of keeping it at the head of the queue.
    case rejected(String)
    var errorDescription: String? {
        switch self {
        case .rejected(let message): message
        case .consentRequired: L10n.text("Vui lòng xác nhận quyền riêng tư và dữ liệu trước khi tiếp tục.")
        case .vaccinationsUnavailable: L10n.text("Tính năng tiêm chủng chưa sẵn sàng trên cloud. Dữ liệu khác vẫn sử dụng được.")
        case .offline: L10n.text("Không kết nối được cloud. Chỉ có thể xem bản lưu trên máy; hãy tải lại khi có mạng.")
        case .accessDenied: L10n.text("Bạn không còn quyền truy cập gia đình này. Hãy chọn lại gia đình hoặc đăng nhập lại.")
        case .signedOut: L10n.text("Phiên đăng nhập đã kết thúc. Hãy đăng nhập lại.")
        case .conflict: L10n.text("Dữ liệu cloud đã thay đổi. Hãy tải lại trước khi lưu tiếp.")
        case .uncertain: L10n.text("Chưa xác nhận được kết quả lưu. Hãy tải lại để đối soát yêu cầu cũ trước khi lưu tiếp.")
        case .busy: L10n.text("Đang xử lý dữ liệu. Hãy chờ thao tác hiện tại hoàn tất.")
        }
    }
    static func isMissingVaccinationEntity(_ error: Error, entity: String) -> Bool {
        guard entity == "vaccinations", let error = error as? PostgrestError else { return false }
        return error.code == "22023" && (error.message == "Invalid read cursor" || error.message == "Unknown entity")
    }
    static func normalize(_ error: Error) -> Error {
        if let e = error as? PostgrestError {
            if e.message == "CONSENT_REQUIRED" { return CloudError.consentRequired }
            if e.code == "P0001", e.message == "Baby limit reached" { return CareDataError.invalidInput(L10n.text("Bạn chỉ có thể tạo tối đa 4 hồ sơ bé.")) }
            if e.code == "40001" || e.code == "23505" { return CloudError.conflict }
            if e.code == "42501" || e.code == "PGRST301" || e.code == "PGRST302" { return CloudError.accessDenied }
            if e.code == "PGRST202" {
                // The message names the function and parameters PostgREST looked for: the server is missing a migration.
                return CareDataError.invalidInput(L10n.text("Server chưa có hàm mà app cần. Hãy áp dụng migration Supabase mới nhất rồi thử lại. ({0})", e.message))
            }
            let message = L10n.text("Cloud từ chối dữ liệu ({0}: {1}). Hãy kiểm tra thông tin rồi thử lại.", "\(e.code ?? "unknown")", e.message)
            // SQLSTATE classes 22 (data exception) and 23 (integrity) and RAISE in our functions are answers about
            // the data, not about the connection; anything else may succeed on retry.
            if let code = e.code, code.hasPrefix("22") || code.hasPrefix("23") || code == "P0001" { return CloudError.rejected(message) }
            return CareDataError.invalidInput(message)
        }
        if error is AuthError { return CloudError.signedOut }
        if let e = error as? StorageError {
            if e.message.contains("CONSENT_REQUIRED") { return CloudError.consentRequired }
            if e.statusCode == "401" || e.statusCode == "403" { return CloudError.accessDenied }
            if e.statusCode == nil || e.statusCode?.hasPrefix("5") == true { return CloudError.offline }
            return CareDataError.invalidInput(L10n.text("Không thể xử lý ảnh trên cloud ({0}).", "\(e.statusCode ?? "unknown")"))
        }
        if let e = error as? URLError, e.code != .cancelled { return CloudError.offline }
        return error
    }
}

nonisolated struct CloudFamily: Codable, Sendable, Identifiable {
    var id: UUID; var name: String; var revision: Int
}

nonisolated enum CloudPrivacyDeletion {
    private struct ObjectPath: Decodable, Sendable { let object_path: String }
    private struct OwnedFamily: Decodable, Sendable { let id: UUID }
    private static let pageSize = 500

    static func removeBabyMedia(client: SupabaseClient, familyID: UUID, babyID: UUID) async throws {
        let paths = try await mediaPaths(client: client, familyID: familyID, babyID: babyID)
        try await remove(paths: paths, client: client)
    }

    static func removeOwnedAccountMedia(client: SupabaseClient, userID: UUID) async throws {
        var offset = 0
        while true {
            let families: [OwnedFamily] = try await client.from("families").select("id")
                .eq("created_by", value: userID).order("id")
                .range(from: offset, to: offset + pageSize - 1).execute().value
            for family in families {
                try await remove(paths: mediaPaths(client: client, familyID: family.id, babyID: nil), client: client)
            }
            guard families.count == pageSize else { break }
            offset += pageSize
        }
    }

    private static func mediaPaths(client: SupabaseClient, familyID: UUID, babyID: UUID?) async throws -> [String] {
        var result: [String] = [], offset = 0
        while true {
            let rows: [ObjectPath]
            if let babyID {
                rows = try await client.from("media_assets").select("object_path")
                    .eq("family_id", value: familyID).eq("baby_id", value: babyID).order("object_path")
                    .range(from: offset, to: offset + pageSize - 1).execute().value
            } else {
                rows = try await client.from("media_assets").select("object_path")
                    .eq("family_id", value: familyID).order("object_path")
                    .range(from: offset, to: offset + pageSize - 1).execute().value
            }
            result += rows.map(\.object_path)
            guard rows.count == pageSize else { break }
            offset += pageSize
        }
        return result
    }

    private static func remove(paths: [String], client: SupabaseClient) async throws {
        let bucket = client.storage.from("babycare-media")
        for start in stride(from: 0, to: paths.count, by: 100) {
            _ = try await bucket.remove(paths: Array(paths[start..<min(start + 100, paths.count)]))
        }
    }
}

nonisolated protocol CareCloudRemote: Sendable {
    func fetch(selected: UUID?) async throws -> CloudSnapshot
    func apply(_ envelope: CloudEnvelope) async throws -> CloudReceipt
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) async throws -> CloudMediaSyncResult
    func deleteBaby(_ id: UUID) async throws
    func invalidate() async
}
extension CareCloudRemote {
    func deleteBaby(_ id: UUID) async throws { throw CareDataError.invalidInput(L10n.text("Cloud chưa hỗ trợ xoá hồ sơ bé.")) }
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
        } catch {
            if envelope.p_changes.contains(where: { $0.entity == "vaccinations" }),
               let backendError = error as? PostgrestError,
               backendError.code == "22023", backendError.message == "Unknown entity" {
                throw CloudError.vaccinationsUnavailable
            }
            throw CloudError.normalize(error)
        }
    }
    func deleteBaby(_ id: UUID) async throws {
        struct Params: Encodable { let p_family_id: UUID; let p_baby_id: UUID }
        do {
            try await lease.check()
            try await CloudPrivacyDeletion.removeBabyMedia(client: client, familyID: familyID, babyID: id)
            try await lease.check()
            _ = try await client.rpc("babycare_delete_baby", params: Params(p_family_id: familyID, p_baby_id: id)).execute()
            try await lease.check()
        } catch { throw CloudError.normalize(error) }
    }
    func syncMedia(from old: CloudSnapshot, to next: CareDatabase, operationID: UUID) async throws -> CloudMediaSyncResult {
        do {
            try await lease.check()
            // Pre-check consent before uploading bytes. Until migration 0008 exists on the server the status RPC is
            // missing (PGRST202); the apply RPC and Storage policies enforce consent themselves once it does.
            do {
                guard try await SupabaseConsentRemote(client: client).status().isCurrent else { throw CloudError.consentRequired }
            } catch let error as PostgrestError where error.code == "PGRST202" { }
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
        struct Params: Encodable { var p_family_id: UUID; var p_entity: String; var p_at_revision: Int; var p_after_id: UUID?; var p_limit = 200; var p_api_version: Int? }
        // Version 2 also returns activity kinds that 1.0.x cannot decode (breathing). A server without
        // migration 0011 has no such rows, so falling back to its old signature loses nothing.
        var readVersion: Int? = CloudMapping.readVersion
        func readPage(_ entity: String, revision: Int, after cursor: UUID?) async throws -> Page {
            do {
                return try await client.rpc("babycare_read_page", params: Params(p_family_id: familyID, p_entity: entity, p_at_revision: revision, p_after_id: cursor, p_api_version: readVersion)).execute().value
            } catch where readVersion != nil && (error as? PostgrestError)?.code == "PGRST202" {
                readVersion = nil
                return try await client.rpc("babycare_read_page", params: Params(p_family_id: familyID, p_entity: entity, p_at_revision: revision, p_after_id: cursor)).execute().value
            }
        }
        do {
            for attempt in 0..<3 {
                do {
                    try await lease.check()
                    let families: [CloudFamily] = try await client.from("families").select().eq("id", value: familyID).execute().value
                    guard let family = families.first else { throw CloudError.accessDenied }
                    var tables: [String: [CloudRow]] = [:]
                    var vaccinationsAvailable = true
                    for entity in CloudMapping.entities {
                        var cursor: UUID?
                        repeat {
                            try await lease.check()
                            let page: Page
                            do {
                                page = try await readPage(entity, revision: family.revision, after: cursor)
                            } catch where CloudError.isMissingVaccinationEntity(error, entity: entity) {
                                vaccinationsAvailable = false
                                break
                            }
                            guard page.revision == family.revision, page.next_after_id == nil || page.next_after_id != cursor else { throw CareDataError.corruptData }
                            tables[entity, default: []].append(contentsOf: page.rows)
                            cursor = page.next_after_id
                        } while cursor != nil
                    }
                    try await lease.check()
                    var snapshot = try CloudMapping.decode(tables, revision: family.revision, selected: selected)
                    snapshot.supportsVaccinations = vaccinationsAvailable
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
