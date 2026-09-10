import Foundation
import SwiftData

nonisolated struct PendingCloudWrite: Codable, Sendable {
    var mutation: CareDataMutation
    var envelope: CloudEnvelope
    var proposed: CareDatabase
}
nonisolated struct CloudCacheState: Codable, Sendable {
    var snapshot: CloudSnapshot?
    /// Kept for decoding caches written before offline queue support.
    var pending: PendingCloudWrite?
    var outbox: [PendingCloudWrite]?

    var queuedWrites: [PendingCloudWrite] {
        get { outbox ?? pending.map { [$0] } ?? [] }
        set {
            outbox = newValue
            pending = nil
        }
    }
}
nonisolated protocol CareCloudCache: Sendable {
    func read() async throws -> CloudCacheState
    func write(_ state: CloudCacheState) async throws
}

@Model final class CloudCacheRecord {
    var payload: Data
    init(payload: Data) { self.payload = payload }
}

/// A separate SwiftData store per project/user/family. Never imports the device store.
actor SwiftDataCloudCache: CareCloudCache {
    private let url: URL
    private var container: ModelContainer?
    init(userID: UUID, familyID: UUID, root: URL = .applicationSupportDirectory) {
        url = root.appending(path: "BabyCare/Cloud/cxlqvuqloaokzmaewvdy/\(userID.uuidString)/\(familyID.uuidString)/Cache.store")
    }
    private func context() throws -> ModelContext {
        if container == nil {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let schema = Schema([CloudCacheRecord.self])
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        }
        guard let container else { throw CareDataError.corruptData }
        let context = ModelContext(container); context.autosaveEnabled = false; return context
    }
    func read() throws -> CloudCacheState {
        let records = try context().fetch(FetchDescriptor<CloudCacheRecord>())
        guard records.count <= 1 else { throw CareDataError.corruptData }
        guard let record = records.first else { return CloudCacheState() }
        return try JSONDecoder().decode(CloudCacheState.self, from: record.payload)
    }
    func write(_ state: CloudCacheState) throws {
        let context = try context()
        let data = try JSONEncoder().encode(state)
        if let record = try context.fetch(FetchDescriptor<CloudCacheRecord>()).first { record.payload = data }
        else { context.insert(CloudCacheRecord(payload: data)) }
        try context.save()
    }
}
