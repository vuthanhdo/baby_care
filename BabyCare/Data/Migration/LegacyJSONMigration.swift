import Foundation

/// The previous JSON file is read-only and retained as a recovery copy.
/// SwiftData owns the completion marker in the same transaction as the import.
nonisolated enum LegacyJSONMigration {
    struct LegacySnapshot: Codable {
        var baby: BabyProfile
        var babies: [BabyProfile]
        var hasOnboarded: Bool
        var archives: [String: LegacyArchive]
    }
    struct LegacyArchive: Codable {
        var activities: [CareActivity]
        var measurements: [BodyMeasurement]
        var isTrackingIllness: Bool
        var illnessTitle: String
        var illnessStartDate: Date
        var sleepStartDate: Date?
        var medicationReminders: [MedicationReminder]
    }

    static func read(_ url: URL) throws -> CareDatabase {
        let source = try Data(contentsOf: url)
        let legacy: LegacySnapshot
        do { legacy = try JSONDecoder().decode(LegacySnapshot.self, from: source) }
        catch { throw CareDataError.corruptData }
        var profiles = legacy.babies
        if let index = profiles.firstIndex(where: { $0.id == legacy.baby.id }) { profiles[index] = legacy.baby }
        else if !legacy.baby.name.isEmpty { profiles.append(legacy.baby) }
        guard Set(profiles.map(\.id)).count == profiles.count else { throw CareDataError.corruptData }
        let profileKeys = Set(profiles.map { $0.id.uuidString })
        for (key, archive) in legacy.archives where !profileKeys.contains(key) {
            // Old installations can have an empty placeholder archive before onboarding.
            // Never silently discard actual records whose owner is missing.
            guard archive.activities.isEmpty, archive.measurements.isEmpty, archive.medicationReminders.isEmpty,
                  !archive.isTrackingIllness, archive.sleepStartDate == nil else { throw CareDataError.corruptData }
        }
        var activityIDs = Set<UUID>(), measurementIDs = Set<UUID>(), reminderIDs = Set<UUID>()
        var babies: [BabyData] = []
        for profile in profiles {
            let archive = legacy.archives[profile.id.uuidString]
            let activities = archive?.activities ?? []
            let measurements = archive?.measurements ?? []
            let reminders = archive?.medicationReminders ?? []
            for activity in activities { guard activityIDs.insert(activity.id).inserted else { throw CareDataError.corruptData } }
            for measurement in measurements { guard measurementIDs.insert(measurement.id).inserted else { throw CareDataError.corruptData } }
            for reminder in reminders { guard reminderIDs.insert(reminder.id).inserted else { throw CareDataError.corruptData } }
            babies.append(BabyData(profile: profile, activities: activities.sorted { $0.date > $1.date },
                measurements: measurements.sorted { $0.date > $1.date }, medicationReminders: reminders,
                isTrackingIllness: archive?.isTrackingIllness ?? false, illnessTitle: archive?.illnessTitle ?? "",
                illnessStartDate: archive?.illnessStartDate ?? Date(), sleepStartDate: archive?.sleepStartDate))
        }
        guard !legacy.hasOnboarded || !babies.isEmpty else { throw CareDataError.corruptData }
        return CareDatabase(babies: babies, selectedBabyID: profiles.contains(where: { $0.id == legacy.baby.id }) ? legacy.baby.id : profiles.first?.id, hasOnboarded: legacy.hasOnboarded)
    }
}
