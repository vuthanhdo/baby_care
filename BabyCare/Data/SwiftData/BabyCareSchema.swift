import Foundation
import SwiftData

enum BabyCareSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [BabyEntity.self, ActivityEntity.self, MeasurementEntity.self, ReminderEntity.self, CareMetadataEntity.self]
    }
}

enum BabyCareSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BabyCareSchemaV1.self, BabyCareSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: BabyCareSchemaV1.self, toVersion: BabyCareSchemaV2.self)] }
}

@Model
nonisolated final class CareMetadataEntity {
    @Attribute(.unique) var key: String
    var selectedBabyID: UUID?
    var hasOnboarded: Bool
    var didImportLegacyJSON: Bool
    init() {
        key = "app"
        selectedBabyID = nil
        hasOnboarded = false
        didImportLegacyJSON = false
    }
}

@Model
nonisolated final class BabyEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date
    var genderRaw: String
    var bloodType: String
    var allergies: String
    var healthNotes: String
    @Attribute(.externalStorage) var avatarData: Data?
    var isTrackingIllness: Bool
    var illnessTitle: String
    var illnessStartDate: Date
    var sleepStartDate: Date?
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \ActivityEntity.baby) var activities: [ActivityEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntity.baby) var measurements: [MeasurementEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \ReminderEntity.baby) var reminders: [ReminderEntity] = []

    init(data: BabyData, sortOrder: Int) {
        id = data.profile.id
        name = data.profile.name
        birthDate = data.profile.birthDate
        genderRaw = data.profile.gender.rawValue
        bloodType = data.profile.bloodType
        allergies = data.profile.allergies
        healthNotes = data.profile.healthNotes
        avatarData = data.profile.avatarData
        isTrackingIllness = data.isTrackingIllness
        illnessTitle = data.illnessTitle
        illnessStartDate = data.illnessStartDate
        sleepStartDate = data.sleepStartDate
        self.sortOrder = sortOrder
    }

    func update(_ data: BabyData) {
        name = data.profile.name
        birthDate = data.profile.birthDate
        genderRaw = data.profile.gender.rawValue
        bloodType = data.profile.bloodType
        allergies = data.profile.allergies
        healthNotes = data.profile.healthNotes
        avatarData = data.profile.avatarData
        isTrackingIllness = data.isTrackingIllness
        illnessTitle = data.illnessTitle
        illnessStartDate = data.illnessStartDate
        sleepStartDate = data.sleepStartDate
    }

    func value() throws -> BabyData {
        guard let gender = BabyGender(rawValue: genderRaw) else { throw CareDataError.corruptData }
        let profile = BabyProfile(id: id, name: name, birthDate: birthDate, gender: gender, bloodType: bloodType,
            allergies: allergies, healthNotes: healthNotes, avatarData: avatarData)
        return try BabyData(profile: profile, activities: activities.map { try $0.value() }.sorted { $0.date > $1.date },
            measurements: measurements.map { $0.value() }.sorted { $0.date > $1.date },
            medicationReminders: reminders.sorted { $0.sortOrder < $1.sortOrder }.map { $0.value() },
            isTrackingIllness: isTrackingIllness, illnessTitle: illnessTitle, illnessStartDate: illnessStartDate, sleepStartDate: sleepStartDate)
    }
}

@Model
nonisolated final class ActivityEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var date: Date
    var valueText: String
    var unit: String
    var note: String
    var detail: String
    @Attribute(.externalStorage) var attachmentData: Data?
    var baby: BabyEntity?

    init(value: CareActivity, baby: BabyEntity) throws {
        id = value.id
        kindRaw = value.kind.rawValue
        date = value.date
        valueText = value.value
        unit = value.unit
        note = value.note
        detail = value.detail
        attachmentData = try Self.encodeAttachments(value.attachments)
        self.baby = baby
    }
    func update(_ value: CareActivity) throws {
        kindRaw = value.kind.rawValue
        date = value.date
        valueText = value.value
        unit = value.unit
        note = value.note
        detail = value.detail
        attachmentData = try Self.encodeAttachments(value.attachments)
    }
    func value() throws -> CareActivity {
        guard let kind = ActivityKind(rawValue: kindRaw) else { throw CareDataError.corruptData }
        let attachments = try attachmentData.map { try PropertyListDecoder().decode([Data].self, from: $0) } ?? []
        return CareActivity(id: id, kind: kind, date: date, value: valueText, unit: unit, note: note, detail: detail, attachments: attachments)
    }
    private static func encodeAttachments(_ attachments: [Data]) throws -> Data? {
        guard !attachments.isEmpty else { return nil }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(attachments)
    }
}

@Model
nonisolated final class MeasurementEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Double?
    var height: Double?
    var headCircumference: Double?
    var method: String
    var notes: String
    var baby: BabyEntity?
    init(value: BodyMeasurement, baby: BabyEntity) {
        id = value.id
        date = value.date
        weight = value.weight
        height = value.height
        headCircumference = value.headCircumference
        method = value.method
        notes = value.notes
        self.baby = baby
    }
    func update(_ value: BodyMeasurement) {
        date = value.date
        weight = value.weight
        height = value.height
        headCircumference = value.headCircumference
        method = value.method
        notes = value.notes
    }
    func value() -> BodyMeasurement {
        BodyMeasurement(id: id, date: date, weight: weight, height: height, headCircumference: headCircumference, method: method, notes: notes)
    }
}

@Model
nonisolated final class ReminderEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: String
    var unit: String
    var nextDate: Date
    var note: String
    var enabled: Bool
    var episodeOnly: Bool
    var sortOrder: Int
    var baby: BabyEntity?
    init(value: MedicationReminder, baby: BabyEntity, sortOrder: Int) {
        id = value.id
        name = value.name
        amount = value.amount
        unit = value.unit
        nextDate = value.nextDate
        note = value.note
        enabled = value.enabled
        episodeOnly = value.episodeOnly
        self.baby = baby
        self.sortOrder = sortOrder
    }
    func update(_ value: MedicationReminder) {
        name = value.name
        amount = value.amount
        unit = value.unit
        nextDate = value.nextDate
        note = value.note
        enabled = value.enabled
        episodeOnly = value.episodeOnly
    }
    func value() -> MedicationReminder {
        MedicationReminder(id: id, name: name, amount: amount, unit: unit, nextDate: nextDate, note: note, enabled: enabled, episodeOnly: episodeOnly)
    }
}

// V1 entities remain unchanged. Vaccinations are owned by babyID in the same store.
enum BabyCareSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { BabyCareSchemaV1.models + [VaccinationEntity.self] }
}

@Model
nonisolated final class VaccinationEntity {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var vaccineName: String
    var date: Date
    var doseNumber: Int
    var nextDoseDate: Date?
    var clinic: String
    var notes: String
    var reminderEnabled: Bool
    var reminderDate: Date?
    init(value: VaccinationRecord, babyID: UUID) {
        id = value.id; self.babyID = babyID
        vaccineName = value.vaccineName; date = value.date; doseNumber = value.doseNumber
        nextDoseDate = value.nextDoseDate; clinic = value.clinic; notes = value.notes
        reminderEnabled = value.reminderEnabled; reminderDate = value.reminderDate
    }
    func update(_ value: VaccinationRecord) {
        vaccineName = value.vaccineName; date = value.date; doseNumber = value.doseNumber
        nextDoseDate = value.nextDoseDate; clinic = value.clinic; notes = value.notes
        reminderEnabled = value.reminderEnabled; reminderDate = value.reminderDate
    }
    func value() -> VaccinationRecord {
        VaccinationRecord(id: id, vaccineName: vaccineName, date: date, doseNumber: doseNumber,
            nextDoseDate: nextDoseDate, clinic: clinic, notes: notes, reminderEnabled: reminderEnabled, reminderDate: reminderDate)
    }
}
