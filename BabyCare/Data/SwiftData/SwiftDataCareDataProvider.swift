import Foundation
import SwiftData

nonisolated struct CarePersistenceConfiguration: Sendable {
    var storeURL: URL
    var legacyJSONURL: URL?
    var inMemory = false

    static var device: Self {
        let directory = URL.applicationSupportDirectory.appending(path: "BabyCare", directoryHint: .isDirectory)
        return Self(storeURL: directory.appending(path: "BabyCare.store"), legacyJSONURL: directory.appending(path: "care-data.json"))
    }
}

/// All ModelContext / @Model access stays on this actor. Only Sendable values leave it.
/// Container creation is lazy so a startup error can be retried without replacing user data.
actor SwiftDataCareDataProvider: CareDataProvider {
    private let configuration: CarePersistenceConfiguration
    private var container: ModelContainer?

    init(configuration: CarePersistenceConfiguration = .device) { self.configuration = configuration }

    func load() async throws -> CareDatabase {
        let context = try preparedContext()
        return try read(context)
    }

    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase {
        try Task.checkCancellation()
        let context = try preparedContext()
        do {
            let current = try read(context)
            let next = try current.applying(mutation)
            try write(next, replacing: current, in: context)
            try Task.checkCancellation()
            try context.save()
            // Do not check cancellation or perform fallible work AFTER the commit.
            return next
        } catch {
            context.rollback()
            throw error
        }
    }

    private func preparedContext() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: BabyCareSchemaV1.self)
            let modelConfiguration: ModelConfiguration
            if configuration.inMemory {
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            } else {
                try FileManager.default.createDirectory(at: configuration.storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                modelConfiguration = ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
            }
            container = try ModelContainer(for: schema, migrationPlan: BabyCareSchemaMigrationPlan.self, configurations: [modelConfiguration])
        }
        guard let container else { throw CareDataError.corruptData }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let metadata = try fetchMetadata(context)
            if !metadata.didImportLegacyJSON {
                let existing = try context.fetchCount(FetchDescriptor<BabyEntity>())
                if let url = configuration.legacyJSONURL, FileManager.default.fileExists(atPath: url.path) {
                    // A legacy import must never overwrite an existing SwiftData database.
                    guard existing == 0 else { throw CareDataError.conflict }
                    let database = try LegacyJSONMigration.read(url)
                    try write(database, replacing: CareDatabase(), in: context)
                }
                metadata.didImportLegacyJSON = true
                try context.save() // Records and migration marker commit together.
            }
            return context
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchMetadata(_ context: ModelContext) throws -> CareMetadataEntity {
        if let metadata = try context.fetch(FetchDescriptor<CareMetadataEntity>()).first { return metadata }
        let metadata = CareMetadataEntity()
        context.insert(metadata)
        return metadata
    }

    private func read(_ context: ModelContext) throws -> CareDatabase {
        let metadata = try fetchMetadata(context)
        let entities = try context.fetch(FetchDescriptor<BabyEntity>(sortBy: [SortDescriptor(\.sortOrder)]))
        let babies = try entities.map { try $0.value() }
        guard metadata.selectedBabyID == nil || babies.contains(where: { $0.profile.id == metadata.selectedBabyID }) else { throw CareDataError.corruptData }
        return CareDatabase(babies: babies, selectedBabyID: metadata.selectedBabyID, hasOnboarded: metadata.hasOnboarded)
    }

    private func write(_ database: CareDatabase, replacing old: CareDatabase, in context: ModelContext) throws {
        let metadata = try fetchMetadata(context)
        metadata.selectedBabyID = database.selectedBabyID
        metadata.hasOnboarded = database.hasOnboarded
        let existing = try context.fetch(FetchDescriptor<BabyEntity>())
        for (order, data) in database.babies.enumerated() {
            guard old.babies.first(where: { $0.profile.id == data.profile.id }) != data else { continue }
            let entity: BabyEntity
            if let saved = existing.first(where: { $0.id == data.profile.id }) { entity = saved; entity.update(data) }
            else { entity = BabyEntity(data: data, sortOrder: order); context.insert(entity) }

            let activities = entity.activities
            for saved in activities where !data.activities.contains(where: { $0.id == saved.id }) { context.delete(saved) }
            for entry in data.activities {
                if let saved = activities.first(where: { $0.id == entry.id }) { try saved.update(entry) }
                else { context.insert(try ActivityEntity(value: entry, baby: entity)) }
            }
            let measurements = entity.measurements
            for saved in measurements where !data.measurements.contains(where: { $0.id == saved.id }) { context.delete(saved) }
            for entry in data.measurements {
                if let saved = measurements.first(where: { $0.id == entry.id }) { saved.update(entry) }
                else { context.insert(MeasurementEntity(value: entry, baby: entity)) }
            }
            let reminders = entity.reminders
            for saved in reminders where !data.medicationReminders.contains(where: { $0.id == saved.id }) { context.delete(saved) }
            for (index, entry) in data.medicationReminders.enumerated() {
                if let saved = reminders.first(where: { $0.id == entry.id }) { saved.update(entry); saved.sortOrder = index }
                else { context.insert(ReminderEntity(value: entry, baby: entity, sortOrder: index)) }
            }
        }
    }
}
