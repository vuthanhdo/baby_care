import Foundation

nonisolated enum BabyGender: String, Codable, Sendable, CaseIterable, Identifiable {
    case girl, boy, unspecified
    var id: Self { self }
    var title: String {
        switch self { case .girl: L10n.text("Bé gái"); case .boy: L10n.text("Bé trai"); case .unspecified: L10n.text("Chưa chọn") }
    }
}

nonisolated struct BabyProfile: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var name = ""
    var birthDate = Date()
    var gender: BabyGender = .unspecified
    var bloodType = "Chưa rõ"
    var allergies = ""
    var healthNotes = ""
    /// Past illnesses, operations, hospital stays or long-term conditions, as the family writes them.
    var medicalHistory = ""
    var avatarData: Data?

    var ageDescription: String { Self.ageText(from: birthDate) }
    /// Shared by the header and the profile forms so both agree on days, months and years.
    static func ageText(from birthDate: Date, at date: Date = Date(), language: AppLanguage = .current) -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: birthDate, to: date)
        let months = max(0, components.month ?? 0)
        if months >= 24 {
            let years = L10n.count(months / 12, one: "1 tuổi", many: "{0} tuổi", language: language)
            guard months % 12 > 0 else { return years }
            return "\(years) \(L10n.count(months % 12, one: "1 tháng", many: "{0} tháng", language: language))"
        }
        let days = max(0, components.day ?? 0)
        if months == 0 { return L10n.count(days, one: "1 ngày tuổi", many: "{0} ngày tuổi", language: language) }
        guard days > 0 else { return L10n.count(months, one: "1 tháng tuổi", many: "{0} tháng tuổi", language: language) }
        // "8 tháng 2 ngày": parents count the first two years in months and days.
        return "\(L10n.count(months, one: "1 tháng", many: "{0} tháng", language: language)) \(L10n.count(days, one: "1 ngày", many: "{0} ngày", language: language))"
    }
    var initial: String { String(name.split(separator: " ").last?.prefix(1) ?? "B").uppercased() }
}

nonisolated enum ActivityGroup: String, Codable, Sendable, CaseIterable, Identifiable {
    case medical, feeding, routine
    var id: Self { self }
    var title: String {
        switch self { case .medical: L10n.text("Y tế"); case .feeding: L10n.text("Ăn uống"); case .routine: L10n.text("Sinh hoạt") }
    }
    var assetName: String {
        switch self { case .medical: "Stitch_stethoscope"; case .feeding: "Stitch_restaurant"; case .routine: "Stitch_nightlight_round" }
    }
}

nonisolated enum ActivityKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case temperature, breathing, medicine, symptom, doctor, allergy, milk, meal, water, sleep, bath, diaper, other
    var id: Self { self }
    var title: String {
        switch self {
        case .temperature: L10n.text("Nhiệt độ")
        case .breathing: L10n.text("Nhịp thở")
        case .medicine: L10n.text("Uống thuốc")
        case .symptom: L10n.text("Triệu chứng")
        case .doctor: L10n.text("Đi khám")
        case .allergy: L10n.text("Dị ứng")
        case .milk: L10n.text("Sữa")
        case .meal: L10n.text("Bữa ăn")
        case .water: L10n.text("Nước")
        case .sleep: L10n.text("Ngủ")
        case .bath: L10n.text("Tắm bé")
        case .diaper: L10n.text("Thay tã / Vệ sinh")
        case .other: L10n.text("Hoạt động khác")
        }
    }
    var group: ActivityGroup {
        switch self {
        case .temperature, .breathing, .medicine, .symptom, .doctor, .allergy: .medical
        case .milk, .meal, .water: .feeding
        case .sleep, .bath, .diaper, .other: .routine
        }
    }
    var assetName: String {
        switch self {
        case .temperature: "Stitch_device_thermostat"
        case .breathing: "Stitch_pulmonology"
        case .medicine: "Stitch_medication"
        case .milk: "Stitch_water_bottle"
        case .sleep: "Stitch_bedtime"
        case .bath: "Stitch_bathtub"
        case .symptom: "Stitch_sick"
        case .doctor: "Stitch_local_hospital"
        case .allergy: "Stitch_warning_amber"
        case .meal: "Stitch_ramen_dining"
        case .water: "Stitch_water_drop"
        case .diaper: "Stitch_baby_changing_station"
        case .other: "Stitch_more_horiz"
        }
    }
    /// Kinds whose `value` is a positive number with a unit.
    static let numericKinds: Set<ActivityKind> = [.temperature, .breathing, .medicine, .milk, .water, .sleep]
    var defaultUnit: String {
        switch self { case .temperature: "°C"; case .breathing: "lần/phút"; case .milk, .water: "ml"; case .sleep: "phút"; default: "" }
    }
}

nonisolated struct CareActivity: Identifiable, Codable, Sendable, Equatable {
    static let recordedSleepDetail = "Thời điểm ghi nhận"
    /// Stored when an entry has no content of its own (a bath, a meal without details).
    static let recordedValue = "Đã ghi nhận"
    var id = UUID()
    var kind: ActivityKind
    var date = Date()
    var value = ""
    var unit = ""
    var note = ""
    var detail = ""
    var attachments: [Data] = []
    /// Doctor visits only: the follow-up appointment the doctor set, reminded two days ahead.
    var followUpDate: Date?
    var numericValue: Double? { CareValidation.number(value) }
    var formattedValue: String {
        let displayValue: String
        switch kind {
        case .symptom: return SymptomCatalog.display(value)
        case .allergy: return AllergyNote(line: value).displayText
        case .meal:
            let parts = [MealEntry.food(self), MealEntry.amount(self)].filter { !$0.isEmpty }
            return parts.isEmpty ? L10n.text(Self.recordedValue) : parts.joined(separator: " · ")
        case .doctor:
            // The diagnosis lives in `unit`; older versions show it after the reason.
            return [value, DoctorVisit.diagnosis(self)].filter { !$0.isEmpty }.joined(separator: " · ")
        case .diaper: displayValue = L10n.text(value)
        default: displayValue = value == Self.recordedValue ? L10n.text(value) : value
        }
        return [displayValue, L10n.text(unit)].filter { !$0.isEmpty }.joined(separator: " ")
    }
    var displayDetail: String {
        switch kind {
        case .temperature: TemperatureDetail(detail).displayText
        case .milk, .sleep, .breathing: L10n.text(detail)
        default: detail
        }
    }
}

nonisolated struct BodyMeasurement: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var date = Date()
    var weight: Double?
    var height: Double?
    var headCircumference: Double?
    var method = ""
    var notes = ""
}


nonisolated struct MedicationReminder: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var name = ""
    var amount = ""
    var unit = "ml"
    var nextDate = Date().addingTimeInterval(3600)
    var note = ""
    var enabled = true
    var episodeOnly = false
}


/// One administered dose, with an optional follow-up appointment and notification.
nonisolated struct VaccinationRecord: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var vaccineName = ""
    var date = Date()
    var doseNumber = 1
    var nextDoseDate: Date?
    var clinic = ""
    var notes = ""
    var reminderEnabled = false
    var reminderDate: Date?
}

// Caches, outboxes and legacy JSON written before 1.1 have no medical history; every other key stays required.
extension BabyProfile {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, birthDate, gender, bloodType, allergies, healthNotes, medicalHistory, avatarData
    }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        birthDate = try c.decode(Date.self, forKey: .birthDate)
        gender = try c.decode(BabyGender.self, forKey: .gender)
        bloodType = try c.decode(String.self, forKey: .bloodType)
        allergies = try c.decode(String.self, forKey: .allergies)
        healthNotes = try c.decode(String.self, forKey: .healthNotes)
        medicalHistory = try c.decodeIfPresent(String.self, forKey: .medicalHistory) ?? ""
        avatarData = try c.decodeIfPresent(Data.self, forKey: .avatarData)
    }
}
