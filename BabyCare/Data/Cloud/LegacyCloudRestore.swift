import Foundation

/// Data from the Supabase project used until 1.3 (5). Its database went down on 4/11/2026 and was not moved to the
/// new backend, but every phone still holds its cloud cache: the last snapshot plus unsent writes, photos included.
/// This finds those caches and turns one into ordinary mutations that rebuild it in the open family, so the upload
/// takes the usual save path: validation, durable outbox, at most 100 records per call, photo upload.
nonisolated enum LegacyCloudRestore {
    struct Backup: Identifiable, Sendable, Equatable {
        /// The cache file; it also identifies the backup.
        let id: URL
        let babyNames: [String]
        let recordCount: Int
        /// When the newest entry happened. Not the file date: opening the store to read it changes that.
        let latestEntry: Date?
    }
    struct Plan: Sendable, Equatable {
        var mutations: [CareDataMutation] = []
        /// Records today's rules refuse (a fifth baby, an entry dated in the future); they are left out.
        var skipped = 0
    }
    /// Entries and photos sent per write: well under the server's 100 records, and a short photo upload each.
    static let entriesPerWrite = 50
    static let photosPerWrite = 20

    static func directory(root: URL = .applicationSupportDirectory) -> URL {
        CloudConfiguration.cacheDirectory(namespace: CloudConfiguration.legacyNamespace, root: root)
    }

    /// Every old cache on this phone that still holds a baby, most recent data first. Unreadable caches are left out.
    static func find(root: URL = .applicationSupportDirectory) async -> [Backup] {
        let files = FileManager.default
        var result: [Backup] = []
        for user in (try? files.contentsOfDirectory(at: directory(root: root), includingPropertiesForKeys: nil)) ?? [] {
            for family in (try? files.contentsOfDirectory(at: user, includingPropertiesForKeys: nil)) ?? [] {
                let file = family.appending(path: "Cache.store")
                guard files.fileExists(atPath: file.path(percentEncoded: false)), let database = await database(at: file), !database.babies.isEmpty else { continue }
                let latest = database.babies.flatMap { $0.activities.map(\.date) + $0.measurements.map(\.date) + $0.vaccinations.map(\.date) }.max()
                result.append(Backup(id: file, babyNames: database.babies.map(\.profile.name), recordCount: count(database), latestEntry: latest))
            }
        }
        return result.sorted { ($0.latestEntry ?? .distantPast) > ($1.latestEntry ?? .distantPast) }
    }

    /// What the phone last showed: the newest unsent write if there is one, else the confirmed snapshot.
    static func database(at file: URL) async -> CareDatabase? {
        guard let state = try? await SwiftDataCloudCache(url: file).read() else { return nil }
        return state.queuedWrites.last?.proposed ?? state.snapshot?.database
    }

    /// Deletes one backup (its family folder) or, given nil, every old cache.
    static func remove(_ backup: Backup?, root: URL = .applicationSupportDirectory) {
        let files = FileManager.default
        guard let backup else { try? files.removeItem(at: directory(root: root)); return }
        let family = backup.id.deletingLastPathComponent(), user = family.deletingLastPathComponent()
        try? files.removeItem(at: family)
        if (try? files.contentsOfDirectory(atPath: user.path(percentEncoded: false)))?.isEmpty == true { try? files.removeItem(at: user) }
    }

    static func count(_ database: CareDatabase) -> Int {
        database.babies.reduce(0) { $0 + 1 + $1.activities.count + $1.measurements.count + $1.vaccinations.count + $1.medicationReminders.count }
    }

    /// The mutations that add to `current` what `source` has and `current` lacks. IDs are derived anew from the
    /// account: two accounts restoring the same backup never collide on the server, while restoring again after an
    /// interruption gives the same IDs and sends only what is still missing. Each mutation is checked against the
    /// reducer here, so one refused record is left out instead of stopping the restore.
    static func plan(restoring source: CareDatabase, into current: CareDatabase, account: UUID) -> Plan {
        var plan = Plan()
        var working = current
        func newID(_ old: UUID) -> UUID { CloudMediaPlan.stableUUID("legacy-restore|\(account.uuidString)|\(old.uuidString)") }
        func add(_ mutation: CareDataMutation) -> Bool {
            guard let next = try? working.applying(mutation) else { return false }
            working = next; plan.mutations.append(mutation); return true
        }
        for baby in source.babies {
            var profile = baby.profile
            profile.id = newID(profile.id)
            let babyID = profile.id
            if !working.babies.contains(where: { $0.profile.id == babyID }), !add(.createBaby(profile)) {
                plan.skipped += count(CareDatabase(babies: [baby])); continue
            }
            guard let restored = working.babies.first(where: { $0.profile.id == babyID }) else { continue }

            let knownActivities = Set(restored.activities.map(\.id))
            var batch: [CareActivity] = [], photos = 0
            func flush() {
                guard !batch.isEmpty else { return }
                if !add(.saveActivities(babyID: babyID, entries: batch)) { plan.skipped += batch.count }
                batch = []; photos = 0
            }
            for activity in baby.activities.sorted(by: { $0.date < $1.date }) {
                var entry = activity
                entry.id = newID(activity.id)
                guard !knownActivities.contains(entry.id) else { continue }
                guard (try? CareValidation.activity(entry)) != nil else { plan.skipped += 1; continue }
                if batch.count == entriesPerWrite || photos + entry.attachments.count > photosPerWrite { flush() }
                batch.append(entry); photos += entry.attachments.count
            }
            flush()

            let knownMeasurements = Set(restored.measurements.map(\.id))
            for measurement in baby.measurements.sorted(by: { $0.date < $1.date }) {
                var entry = measurement
                entry.id = newID(measurement.id)
                guard !knownMeasurements.contains(entry.id) else { continue }
                if !add(.saveMeasurement(babyID: babyID, measurement: entry)) { plan.skipped += 1 }
            }

            let knownVaccinations = Set(restored.vaccinations.map(\.id))
            for vaccination in baby.vaccinations.sorted(by: { $0.date < $1.date }) {
                var record = vaccination
                record.id = newID(vaccination.id)
                guard !knownVaccinations.contains(record.id) else { continue }
                if !add(.saveVaccination(babyID: babyID, record: record)) { plan.skipped += 1 }
            }

            let knownReminders = Set(restored.medicationReminders.map(\.id))
            for reminder in baby.medicationReminders {
                var entry = reminder
                entry.id = newID(reminder.id)
                guard !knownReminders.contains(entry.id) else { continue }
                // A reminder whose time passed while the old server was down comes back switched off, not lost.
                if entry.enabled && entry.nextDate <= Date() { entry.enabled = false }
                if !add(.saveReminder(babyID: babyID, reminder: entry)) { plan.skipped += 1 }
            }

            // An illness still being followed carries on; a sleep left running since then does not.
            if baby.isTrackingIllness, !restored.isTrackingIllness {
                _ = add(.startIllness(babyID: babyID, title: baby.illnessTitle, date: baby.illnessStartDate))
            }
        }
        return plan
    }
}
