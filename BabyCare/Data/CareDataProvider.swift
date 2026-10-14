import Foundation

/// Implement this contract to switch to an HTTP/cloud database in AppDependencies.
/// Return committed value snapshots; throw without publishing partial writes.
/// Keep UUIDs stable, scope every mutation to its baby, and apply a batch atomically.
protocol CareDataProvider: Sendable {
    func load() async throws -> CareDatabase
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase
    func status() async -> CareStorageStatus
    func supportsVaccinations() async -> Bool
    func invalidate() async
}

extension CareDataProvider {
    func status() async -> CareStorageStatus { .device }
    func supportsVaccinations() async -> Bool { true }
    func invalidate() async {}
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
