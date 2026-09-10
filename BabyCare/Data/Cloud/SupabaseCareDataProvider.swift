import Foundation

nonisolated enum CareStorageStatus: Equatable, Sendable {
    case device, cloud, cached, pending, cacheWarning
    var message: String? {
        switch self {
        case .device: nil
        case .cloud: "Dữ liệu cloud"
        case .cached: "Đang xem bản lưu trên máy"
        case .pending: "Đã lưu trên máy · Đang chờ đồng bộ cloud"
        case .cacheWarning: "Đã lưu cloud · Chưa cập nhật được bản lưu trên máy"
        }
    }
}

/// Cloud-first when connected, optimistic + durable outbox while offline.
actor SupabaseCareDataProvider: CareDataProvider {
    private let remote: any CareCloudRemote
    private let cache: any CareCloudCache
    private let familyID: UUID
    private let retryDelay: Duration
    private var state = CloudCacheState()
    private var storage: CareStorageStatus = .cloud
    private var loaded = false
    private var busy = false
    private var active = true
    private var retryTask: Task<Void, Never>?

    init(remote: any CareCloudRemote, cache: any CareCloudCache, familyID: UUID,
         retryDelay: Duration = .seconds(10)) {
        self.remote = remote; self.cache = cache; self.familyID = familyID
        self.retryDelay = retryDelay
    }
    deinit { retryTask?.cancel() }

    func status() async -> CareStorageStatus { storage }
    func invalidate() async {
        active = false; retryTask?.cancel(); retryTask = nil
        await remote.invalidate()
    }
    private func check() throws { guard active else { throw CloudError.signedOut }; try Task.checkCancellation() }
    private func prepare() async throws {
        if !loaded {
            state = try await cache.read()
            if state.outbox == nil, state.pending != nil {
                state.queuedWrites = state.queuedWrites
                try await cache.write(state)
            }
            loaded = true
        }
        try check()
    }
    private var visibleDatabase: CareDatabase? { state.queuedWrites.last?.proposed ?? state.snapshot?.database }

    func load() async throws -> CareDatabase {
        guard !busy else { throw CloudError.busy }; busy = true; defer { busy = false }
        try await prepare()
        do {
            try await flushQueuedWrites(allowRebase: true)
            let fetched = try await remote.fetch(selected: visibleDatabase?.selectedBabyID)
            try check()
            state.snapshot = fetched; state.queuedWrites = []; storage = .cloud
            do { try await cache.write(state) } catch { storage = .cacheWarning }
            try check()
            return fetched.database
        } catch {
            try check()
            if error as? CloudError == .accessDenied {
                state = CloudCacheState(); try await cache.write(state)
            }
            if error as? CloudError == .offline, let visibleDatabase {
                storage = state.queuedWrites.isEmpty ? .cached : .pending
                if !state.queuedWrites.isEmpty { scheduleRetry() }
                return visibleDatabase
            }
            throw error
        }
    }

    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase {
        guard !busy else { throw CloudError.busy }; busy = true; defer { busy = false }
        try await prepare()
        guard let committed = state.snapshot, let current = visibleDatabase else { throw CloudError.offline }
        let next = try current.applying(mutation)
        if case .selectBaby = mutation {
            state.snapshot?.database.selectedBabyID = next.selectedBabyID
            var queue = state.queuedWrites
            for index in queue.indices { queue[index].proposed.selectedBabyID = next.selectedBabyID }
            state.queuedWrites = queue
            try await cache.write(state); try check(); return next
        }
        _ = try CloudMediaPlan.desired(in: next, familyID: familyID) // Validate before any network write.
        let workingBase = CloudSnapshot(database: current, versions: committed.versions, revision: committed.revision)
        let localChanges = try CloudMapping.changes(from: workingBase, to: next)
        guard !localChanges.isEmpty || CloudMediaPlan.hasChanges(from: current, to: next) else { return current }
        var queue = state.queuedWrites
        let changes = queue.isEmpty ? localChanges : []
        queue.append(PendingCloudWrite(mutation: mutation,
            envelope: CloudEnvelope(p_family_id: familyID, p_changes: changes), proposed: next))
        state.queuedWrites = queue
        try await cache.write(state) // Durable before any network attempt.
        try check()
        do {
            try await flushQueuedWrites(allowRebase: true)
        } catch where error as? CloudError == .offline || error as? CloudError == .uncertain {
            storage = .pending; scheduleRetry(); return next
        }
        return visibleDatabase ?? next
    }

    /// The UI already contains the optimistic data; this drains only the durable queue.
    @discardableResult
    func syncPendingWrites() async throws -> CareDatabase {
        guard !busy else { throw CloudError.busy }; busy = true; defer { busy = false }
        try await prepare()
        try await flushQueuedWrites(allowRebase: true)
        guard let visibleDatabase else { throw CloudError.offline }
        return visibleDatabase
    }

    private func flushQueuedWrites(allowRebase: Bool) async throws {
        while var pending = state.queuedWrites.first {
            try check()
            guard let committed = state.snapshot else { throw CloudError.offline }
            if pending.envelope.p_changes.isEmpty {
                let changes = try CloudMapping.changes(from: committed, to: pending.proposed)
                if changes.isEmpty && !CloudMediaPlan.hasChanges(from: committed.database, to: pending.proposed) {
                    var queue = state.queuedWrites; queue.removeFirst(); state.queuedWrites = queue
                    try await cache.write(state); continue
                }
                pending.envelope.p_changes = changes
                var queue = state.queuedWrites; queue[0] = pending; state.queuedWrites = queue
                try await cache.write(state) // Freeze this idempotent request before sending.
            }
            let receipt: CloudReceipt
            do {
                if pending.envelope.p_changes.isEmpty {
                    receipt = CloudReceipt(operation_id: pending.envelope.p_operation_id,
                                           revision: committed.revision, records: [])
                } else {
                    receipt = try await remote.apply(pending.envelope)
                }
            } catch {
                try check()
                if error as? CloudError == .conflict, allowRebase {
                    try await rebaseQueue()
                    try await flushQueuedWrites(allowRebase: false)
                    return
                }
                if error as? CloudError == .accessDenied {
                    state = CloudCacheState(); try await cache.write(state)
                } else { storage = .pending }
                throw error
            }
            try check()
            guard receipt.operation_id == pending.envelope.p_operation_id else { throw CareDataError.corruptData }
            let media: CloudMediaSyncResult
            do {
                media = try await remote.syncMedia(from: committed, to: pending.proposed,
                                                  operationID: pending.envelope.p_operation_id)
            } catch {
                try check()
                if error as? CloudError == .accessDenied {
                    state = CloudCacheState(); try await cache.write(state)
                } else { storage = .pending }
                throw error
            }
            try check()
            var acknowledged = committed
            acknowledged.database = pending.proposed
            acknowledged.revision = max(receipt.revision, media.revision)
            acknowledged.mediaAssets = media.assets
            for record in receipt.records + media.records {
                acknowledged.versions[CloudSnapshot.key(record.entity, record.id)] = record.version
            }
            var queue = state.queuedWrites; queue.removeFirst()
            state.snapshot = acknowledged; state.queuedWrites = queue
            storage = queue.isEmpty ? .cloud : .pending
            do { try await cache.write(state) }
            catch {
                // The backend deduplicates the stale journal by operation ID on retry.
                storage = .cacheWarning; scheduleRetry(); return
            }
        }
        if storage != .cacheWarning { storage = .cloud }
    }

    private func rebaseQueue() async throws {
        let fetched = try await remote.fetch(selected: visibleDatabase?.selectedBabyID)
        var database = fetched.database
        var queue = state.queuedWrites
        for index in queue.indices {
            database = try database.applying(queue[index].mutation)
            queue[index].proposed = database
            queue[index].envelope.p_changes = []
        }
        state.snapshot = fetched; state.queuedWrites = queue
        try await cache.write(state)
    }

    private func scheduleRetry() {
        guard retryTask == nil, active, !state.queuedWrites.isEmpty else { return }
        let delay = retryDelay
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                if await self.retryOnce() { return }
            }
        }
    }
    private func retryOnce() async -> Bool {
        guard active else { retryTask = nil; return true }
        guard !busy else { return false }
        do {
            _ = try await syncPendingWrites()
            if state.queuedWrites.isEmpty { retryTask = nil; return true }
        } catch let error as CloudError where error == .accessDenied || error == .signedOut {
            retryTask = nil; return true
        } catch { }
        return false
    }
}
