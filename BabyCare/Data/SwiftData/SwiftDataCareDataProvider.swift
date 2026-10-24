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
            let schema = Schema(versionedSchema: BabyCareSchemaV3.self)
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
        var babies = try entities.map { try $0.value() }
        let vaccinations = try context.fetch(FetchDescriptor<VaccinationEntity>())
        guard vaccinations.allSatisfy({ v in babies.contains { $0.profile.id == v.babyID } }) else { throw CareDataError.corruptData }
        let details = try context.fetch(FetchDescriptor<BabyDetailsEntity>())
        let followUps = try context.fetch(FetchDescriptor<ActivityFollowUpEntity>())
        guard details.allSatisfy({ d in babies.contains { $0.profile.id == d.babyID } }),
              followUps.allSatisfy({ f in babies.contains { $0.profile.id == f.babyID } }) else { throw CareDataError.corruptData }
        for index in babies.indices {
            let babyID = babies[index].profile.id
            babies[index].vaccinations = vaccinations.filter { $0.babyID == babyID }.map { $0.value() }.sorted { $0.date > $1.date }
            babies[index].profile.medicalHistory = details.first { $0.babyID == babyID }?.medicalHistory ?? ""
            for follow in followUps where follow.babyID == babyID {
                guard let activity = babies[index].activities.firstIndex(where: { $0.id == follow.activityID }) else { throw CareDataError.corruptData }
                babies[index].activities[activity].followUpDate = follow.date
            }
        }
        guard metadata.selectedBabyID == nil || babies.contains(where: { $0.profile.id == metadata.selectedBabyID }) else { throw CareDataError.corruptData }
        return CareDatabase(babies: babies, selectedBabyID: metadata.selectedBabyID, hasOnboarded: metadata.hasOnboarded)
    }

    private func write(_ database: CareDatabase, replacing old: CareDatabase, in context: ModelContext) throws {
        let metadata = try fetchMetadata(context)
        metadata.selectedBabyID = database.selectedBabyID
        metadata.hasOnboarded = database.hasOnboarded
        let vaccinationEntities = try context.fetch(FetchDescriptor<VaccinationEntity>())
        let wantedIDs = Set(database.babies.flatMap(\.vaccinations).map(\.id))
        for saved in vaccinationEntities where !wantedIDs.contains(saved.id) { context.delete(saved) }
        for baby in database.babies {
            for record in baby.vaccinations {
                if let saved = vaccinationEntities.first(where: { $0.id == record.id }) {
                    guard saved.babyID == baby.profile.id else { throw CareDataError.conflict }
                    saved.update(record)
                } else { context.insert(VaccinationEntity(value: record, babyID: baby.profile.id)) }
            }
        }
        try writeDetails(database, in: context)
        let existing = try context.fetch(FetchDescriptor<BabyEntity>())
        let wantedBabyIDs = Set(database.babies.map(\.profile.id))
        for saved in existing where !wantedBabyIDs.contains(saved.id) { context.delete(saved) }
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

    /// Side-table rows follow the records they extend: removed records and emptied fields delete their row.
    private func writeDetails(_ database: CareDatabase, in context: ModelContext) throws {
        let details = try context.fetch(FetchDescriptor<BabyDetailsEntity>())
        let wantedDetails = Dictionary(uniqueKeysWithValues: database.babies.compactMap { baby in
            baby.profile.medicalHistory.isEmpty ? nil : (baby.profile.id, baby.profile.medicalHistory)
        })
        for saved in details where wantedDetails[saved.babyID] == nil { context.delete(saved) }
        for (babyID, history) in wantedDetails {
            if let saved = details.first(where: { $0.babyID == babyID }) { saved.medicalHistory = history }
            else { context.insert(BabyDetailsEntity(babyID: babyID, medicalHistory: history)) }
        }
        let followUps = try context.fetch(FetchDescriptor<ActivityFollowUpEntity>())
        var wantedFollowUps: [UUID: (babyID: UUID, date: Date)] = [:]
        for baby in database.babies {
            for activity in baby.activities { if let date = activity.followUpDate { wantedFollowUps[activity.id] = (baby.profile.id, date) } }
        }
        for saved in followUps where wantedFollowUps[saved.activityID] == nil { context.delete(saved) }
        for (activityID, wanted) in wantedFollowUps {
            if let saved = followUps.first(where: { $0.activityID == activityID }) {
                guard saved.babyID == wanted.babyID else { throw CareDataError.conflict }
                saved.date = wanted.date
            } else { context.insert(ActivityFollowUpEntity(activityID: activityID, babyID: wanted.babyID, date: wanted.date)) }
        }
    }
}
