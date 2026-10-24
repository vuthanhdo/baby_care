import Foundation

/// Implement this contract to switch to an HTTP/cloud database in AppDependencies.
/// Return committed value snapshots; throw without publishing partial writes.
/// Keep UUIDs stable, scope every mutation to its baby, and apply a batch atomically.
nonisolated protocol CareDataProvider: Sendable {
    func load() async throws -> CareDatabase
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase
    func status() async -> CareStorageStatus
    func supportsVaccinations() async -> Bool
    func invalidate() async
    /// What the screens should show after a failed write, when the provider knows better than the last result.
    func currentDatabase() async -> CareDatabase?
    /// A one-time message about earlier writes the backend refused and the provider dropped.
    func takeNotice() async -> String?
}

extension CareDataProvider {
    func status() async -> CareStorageStatus { .device }
    func supportsVaccinations() async -> Bool { true }
    func invalidate() async {}
    func currentDatabase() async -> CareDatabase? { nil }
    func takeNotice() async -> String? { nil }
}

/// Previews/tests use the identical contract without touching the user's database.
actor InMemoryCareDataProvider: CareDataProvider {
    private var database: CareDatabase
    init(database: CareDatabase = CareDatabase()) { self.database = database }
    func load() async throws -> CareDatabase { database }
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase {
        try Task.checkCancellation()
        database = try database.applying(mutation)
        return database
    }
}
