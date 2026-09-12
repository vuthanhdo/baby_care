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
    var avatarData: Data?

    var ageDescription: String {
        let months = Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
        if months == 0 {
            let days = Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
            return L10n.text("{0} ngày tuổi", "\(max(0, days))")
        }
        return L10n.text("{0} tháng tuổi", "\(months)")
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
    case temperature, medicine, symptom, doctor, allergy, milk, meal, water, sleep, bath, diaper, other
    var id: Self { self }
    var title: String {
        switch self {
        case .temperature: L10n.text("Nhiệt độ")
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
        case .temperature, .medicine, .symptom, .doctor, .allergy: .medical
        case .milk, .meal, .water: .feeding
        case .sleep, .bath, .diaper, .other: .routine
        }
    }
    var assetName: String {
        switch self {
        case .temperature: "Stitch_device_thermostat"
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
    var defaultUnit: String {
        switch self { case .temperature: "°C"; case .milk, .water: "ml"; case .sleep: "phút"; default: "" }
    }
}

nonisolated struct CareActivity: Identifiable, Codable, Sendable, Equatable {
    static let recordedSleepDetail = "Thời điểm ghi nhận"
    var id = UUID()
    var kind: ActivityKind
    var date = Date()
    var value = ""
    var unit = ""
    var note = ""
    var detail = ""
    var attachments: [Data] = []
    var numericValue: Double? { CareValidation.number(value) }
    var formattedValue: String {
        let displayValue: String
        switch kind {
        case .symptom: displayValue = value.components(separatedBy: ", ").map { L10n.text($0) }.joined(separator: ", ")
        case .diaper: displayValue = L10n.text(value)
        default: displayValue = value == "Đã ghi nhận" ? L10n.text(value) : value
        }
        return [displayValue, L10n.text(unit)].filter { !$0.isEmpty }.joined(separator: " ")
    }
    var displayDetail: String {
        switch kind {
        case .temperature, .milk, .sleep: L10n.text(detail)
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

