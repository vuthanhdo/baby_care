import Foundation

nonisolated enum CarePreviewData {
    static func make() -> CareDatabase {
        let profile = BabyProfile(name: "Bé An", birthDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!, gender: .girl)
        var data = BabyData(profile: profile)
        let now = Date()
        data.activities = [
            CareActivity(kind: .temperature, date: now.addingTimeInterval(-3600), value: "37,7", unit: "°C", note: "Trán ấm, chơi ngoan", detail: "Đo nách"),
            CareActivity(kind: .symptom, date: now.addingTimeInterval(-5400), value: "Ho, Sổ mũi", note: "Ho nhẹ về đêm"),
            CareActivity(kind: .medicine, date: now.addingTimeInterval(-21600), value: "5", unit: "ml", detail: "Paracetamol"),
            CareActivity(kind: .bath, date: now.addingTimeInterval(-7200), value: "Tắm nước ấm", note: "Bé thoải mái sau khi tắm"),
            CareActivity(kind: .sleep, date: now.addingTimeInterval(-14400), value: "90", unit: "phút", note: "Ngủ tròn giấc, dậy vui"),
            CareActivity(kind: .milk, date: now.addingTimeInterval(-18000), value: "120", unit: "ml", note: "Bé bú hết bình", detail: "Sữa công thức"),
            CareActivity(kind: .temperature, date: now.addingTimeInterval(-20000), value: "37,9", unit: "°C", detail: "Đo nách"),
            CareActivity(kind: .temperature, date: now.addingTimeInterval(-28000), value: "38,2", unit: "°C", detail: "Đo nách")
        ]
        data.measurements = [
            BodyMeasurement(date: now, weight: 9.5, height: 75, headCircumference: 45.2),
            BodyMeasurement(date: now.addingTimeInterval(-30 * 86400), weight: 9.1, height: 73.5, headCircumference: 44.8),
            BodyMeasurement(date: now.addingTimeInterval(-60 * 86400), weight: 8.8, height: 72, headCircumference: 44.5)
        ]
        data.isTrackingIllness = true
        data.illnessTitle = "Theo dõi sức khỏe của bé"
        data.illnessStartDate = now.addingTimeInterval(-86400)
        return CareDatabase(babies: [data], selectedBabyID: profile.id, hasOnboarded: true)
    }
}
