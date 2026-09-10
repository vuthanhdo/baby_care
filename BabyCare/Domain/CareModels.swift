import Foundation

nonisolated enum BabyGender: String, Codable, Sendable, CaseIterable, Identifiable {
    case girl, boy, unspecified
    var id: Self { self }
    var title: String {
        switch self { case .girl: "Bé gái"; case .boy: "Bé trai"; case .unspecified: "Chưa chọn" }
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
            return "\(max(0, days)) ngày tuổi"
        }
        return "\(months) tháng tuổi"
    }
    var initial: String { String(name.split(separator: " ").last?.prefix(1) ?? "B").uppercased() }
}

nonisolated enum ActivityGroup: String, Codable, Sendable, CaseIterable, Identifiable {
    case medical, feeding, routine
    var id: Self { self }
    var title: String {
        switch self { case .medical: "Y tế"; case .feeding: "Ăn uống"; case .routine: "Sinh hoạt" }
    }
    var assetName: String {
        switch self { case .medical: "HomeIcon12"; case .feeding: "HomeIcon14"; case .routine: "HomeIcon16" }
    }
}

nonisolated enum ActivityKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case temperature, medicine, symptom, doctor, allergy, milk, meal, water, sleep, bath, diaper, other
    var id: Self { self }
    var title: String {
        switch self {
        case .temperature: "Nhiệt độ"
        case .medicine: "Uống thuốc"
        case .symptom: "Triệu chứng"
        case .doctor: "Đi khám"
        case .allergy: "Dị ứng"
        case .milk: "Sữa"
        case .meal: "Bữa ăn"
        case .water: "Nước"
        case .sleep: "Ngủ"
        case .bath: "Tắm bé"
        case .diaper: "Thay tã / Vệ sinh"
        case .other: "Hoạt động khác"
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
        case .temperature: "HomeIcon20"
        case .medicine: "HomeIcon21"
        case .milk: "HomeIcon8"
        case .sleep: "HomeIcon10"
        case .bath: "DiaryIcon13"
        default: group.assetName
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
    var formattedValue: String { [value, unit].filter { !$0.isEmpty }.joined(separator: " ") }
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

