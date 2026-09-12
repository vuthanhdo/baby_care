import CryptoKit
import Foundation

nonisolated enum CloudMediaPurpose: String, Codable, Sendable { case avatar, activity }

nonisolated struct CloudMediaAsset: Codable, Sendable, Equatable {
    var id: UUID
    var babyID: UUID
    var activityID: UUID?
    var purpose: CloudMediaPurpose
    var objectPath: String
    var mimeType: String
    var byteCount: Int
    var version: Int
    var status: String
    var contentHash: String?
    var position: Int?
}

nonisolated struct CloudMediaUpload: Sendable {
    var asset: CloudMediaAsset
    var data: Data
}

nonisolated struct CloudMediaSyncResult: Sendable {
    var assets: [CloudMediaAsset]
    var revision: Int
    var records: [CloudReceipt.Record]
}

nonisolated enum CloudMediaPlan {
    static let maximumBytes = 5 * 1_024 * 1_024

    static func desired(in database: CareDatabase, familyID: UUID, operationID: UUID? = nil,
                        existing: [CloudMediaAsset] = []) throws -> [CloudMediaUpload] {
        var result: [CloudMediaUpload] = []
        for baby in database.babies {
            if let data = baby.profile.avatarData {
                result.append(try upload(data: data, purpose: .avatar, familyID: familyID,
                                         babyID: baby.profile.id, activityID: nil, position: 0, operationID: operationID, existing: existing))
            }
            for activity in baby.activities {
                for (index, data) in activity.attachments.enumerated() {
                    result.append(try upload(data: data, purpose: .activity, familyID: familyID,
                                             babyID: baby.profile.id, activityID: activity.id, position: index, operationID: operationID, existing: existing))
                }
            }
        }
        return result
    }

    static func hasChanges(from old: CareDatabase, to next: CareDatabase) -> Bool {
        // A damaged cache must never hit Dictionary's duplicate-key precondition.
        guard Set(old.babies.map(\.profile.id)).count == old.babies.count,
              Set(next.babies.map(\.profile.id)).count == next.babies.count,
              (old.babies + next.babies).allSatisfy({ Set($0.activities.map(\.id)).count == $0.activities.count }) else { return true }
        let oldBabies = Dictionary(uniqueKeysWithValues: old.babies.map { ($0.profile.id, $0) })
        let nextBabies = Dictionary(uniqueKeysWithValues: next.babies.map { ($0.profile.id, $0) })
        for id in Set(oldBabies.keys).union(nextBabies.keys) {
            guard let before = oldBabies[id], let after = nextBabies[id] else {
                if oldBabies[id]?.profile.avatarData != nil || nextBabies[id]?.profile.avatarData != nil { return true }
                continue
            }
            if before.profile.avatarData != after.profile.avatarData { return true }
            let oldActivities = Dictionary(uniqueKeysWithValues: before.activities.map { ($0.id, $0.attachments) })
            let newActivities = Dictionary(uniqueKeysWithValues: after.activities.map { ($0.id, $0.attachments) })
            if oldActivities != newActivities { return true }
        }
        return false
    }

    private static func upload(data: Data, purpose: CloudMediaPurpose, familyID: UUID,
                               babyID: UUID, activityID: UUID?, position: Int, operationID: UUID?,
                               existing: [CloudMediaAsset]) throws -> CloudMediaUpload {
        guard !data.isEmpty, data.count <= maximumBytes else {
            throw CareDataError.invalidInput(L10n.text("Mỗi ảnh cần nhỏ hơn 5 MB."))
        }
        guard let mimeType = mimeType(of: data) else {
            throw CareDataError.invalidInput(L10n.text("Ảnh phải có định dạng JPEG, PNG, HEIC hoặc WebP."))
        }
        let owner = activityID?.uuidString ?? babyID.uuidString
        let hash = contentHash(data)
        if let asset = existing.first(where: {
            $0.babyID == babyID && $0.activityID == activityID && $0.purpose == purpose
                && $0.contentHash == hash && $0.position == position && $0.status == "ready"
        }) { return CloudMediaUpload(asset: asset, data: data) }
        // Include the durable write ID so selecting a previously deleted image creates a new asset.
        var id = stableUUID("media|\(familyID)|\(operationID?.uuidString ?? "validation")|\(purpose.rawValue)|\(owner)|\(position)|\(hash)")
        var bytes = id.uuid
        bytes.0 = UInt8(clamping: position)
        id = UUID(uuid: bytes) // Preserve attachment order in the server's UUID-sorted read pages.
        let path = "\(familyID.uuidString.lowercased())/\(babyID.uuidString.lowercased())/\(id.uuidString.lowercased())"
        return CloudMediaUpload(asset: CloudMediaAsset(id: id, babyID: babyID, activityID: activityID,
            purpose: purpose, objectPath: path, mimeType: mimeType, byteCount: data.count, version: 0,
            status: "pending", contentHash: hash, position: position), data: data)
    }

    static func contentHash(_ data: Data) -> String { SHA256.hash(data: data).hex }

    static func operationID(assetID: UUID, stage: String) -> UUID {
        stableUUID("media-operation|\(assetID.uuidString)|\(stage)")
    }

    private static func stableUUID(_ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func mimeType(of data: Data) -> String? {
        let bytes = [UInt8](data.prefix(16))
        if bytes.starts(with: [0xff, 0xd8, 0xff]) { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) { return "image/png" }
        if bytes.count >= 12, String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" { return "image/webp" }
        if bytes.count >= 12, String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" {
            let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
            if ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) { return "image/heic" }
        }
        return nil
    }
}

private extension SHA256.Digest {
    nonisolated var hex: String { map { String(format: "%02x", $0) }.joined() }
}
