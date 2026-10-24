import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum CarePreviewData {
    /// The small fixture previews and UI tests rely on: one baby, one open episode, a few entries.
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

    /// Three babies with a month of routine, an open illness episode, reminders, growth history and the
    /// national vaccination schedule, so every screen and state has something to show.
    /// Deterministic for a given `now`; nothing is dated after it and nothing precedes a birth.
    static func showcase(now: Date = Date()) -> CareDatabase {
        var builder = ShowcaseBuilder(now: now)
        let an = builder.an()
        let minh = builder.minh()
        let bo = builder.bo()
        return CareDatabase(babies: [an, minh, bo], selectedBabyID: an.profile.id, hasOnboarded: true)
    }
}

/// SplitMix64: the same seed always yields the same sample data.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private nonisolated struct ShowcaseBuilder {
    let now: Date
    let calendar = Calendar.current
    var rng = SeededGenerator(seed: 2026)
    /// Entries before this moment are dropped (the baby's birth).
    var floor = Date.distantPast

    init(now: Date) { self.now = now }

    // MARK: Time and value helpers

    func day(_ daysAgo: Int) -> Date { calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now }
    func at(_ daysAgo: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(daysAgo)) ?? now
    }
    func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
    func months(_ count: Int, after date: Date, days: Int = 0) -> Date {
        let base = calendar.date(byAdding: .month, value: count, to: date) ?? date
        return calendar.date(byAdding: .day, value: days, to: base) ?? base
    }
    func days(_ count: Int, after date: Date) -> Date { calendar.date(byAdding: .day, value: count, to: date) ?? date }
    func isWeekend(_ date: Date) -> Bool { [1, 7].contains(calendar.component(.weekday, from: date)) }
    mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &rng) }
    mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }
    mutating func jitter(_ date: Date, minutes: Int) -> Date { date.addingTimeInterval(TimeInterval(int(-minutes...minutes) * 60)) }

    /// Adds `entry` unless it lies in the future or before the birth; sleeps must also have ended.
    func add(_ entry: CareActivity, to list: inout [CareActivity]) {
        guard entry.date <= now, entry.date >= floor else { return }
        if entry.kind == .sleep, let minutes = entry.numericValue, entry.date.addingTimeInterval(minutes * 60) > now { return }
        list.append(entry)
    }

    func vaccination(_ name: String, dose: Int, at date: Date, clinic: String, notes: String = "",
                     next: Date? = nil, remind: Bool = false) -> VaccinationRecord? {
        guard date >= floor, date <= now else { return nil }
        let next = next.flatMap { $0 > date ? $0 : nil }
        return VaccinationRecord(vaccineName: name, date: date, doseNumber: dose, nextDoseDate: next, clinic: clinic, notes: notes,
                                 reminderEnabled: remind && next != nil, reminderDate: remind ? next.map { days(-1, after: $0) } : nil)
    }

    func finish(_ baby: inout BabyData) {
        baby.activities.sort { $0.date > $1.date }
        baby.measurements.sort { $0.date > $1.date }
        baby.vaccinations.sort { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }

    // MARK: Bé An · 11 months, open fever episode

    mutating func an() -> BabyData {
        let birth = months(-11, after: now, days: -12)
        floor = birth
        var profile = BabyProfile(name: "Bé An", birthDate: birth, gender: .girl, bloodType: "O",
                                  allergies: "Trứng gà · Nhẹ · Nghi ngờ",
                                  healthNotes: "Ngủ đêm từ 20:30, thích nghe nhạc ru. Vitamin D3 mỗi sáng sau cữ bú đầu.",
                                  medicalHistory: "Sinh đủ tháng (39 tuần), 3,2 kg. Viêm tiểu phế quản lúc 6 tháng, điều trị ngoại trú.")
        profile.avatarData = CarePreviewImages.avatar(emoji: "👧", hue: 0.93)
        var baby = BabyData(profile: profile)

        var list = routineAn(days: 30, illnessDays: 3)
        list += episodeAn()
        add(CareActivity(kind: .allergy, date: at(20, 12, 30), value: "Trứng gà · Nhẹ · Nghi ngờ",
                         note: "Nổi mẩn đỏ quanh miệng sau khi ăn trứng. Hết sau 2 giờ, không khó thở. Tạm ngưng trứng 2 tuần rồi thử lại."), to: &list)
        add(CareActivity(kind: .doctor, date: at(26, 9, 0), value: "Khám định kỳ 10 tháng",
                         note: "Phát triển tốt, bắt đầu tập đứng. Dặn bổ sung thêm bữa phụ."), to: &list)
        baby.activities = list

        let weights = [3.2, 4.2, 5.1, 5.8, 6.4, 6.9, 7.3, 7.6, 7.9, 8.2, 8.5, 8.7]
        let heights = [49.1, 53.7, 57.1, 59.8, 62.1, 64.0, 65.7, 67.3, 68.7, 70.1, 71.5, 72.8]
        let heads = [33.9, 36.5, 38.3, 39.5, 40.6, 41.5, 42.2, 42.8, 43.4, 43.8, 44.2, 44.6]
        for month in 0..<12 {
            let date = month == 0 ? birth : months(month, after: birth, days: int(0...3))
            guard date <= now else { continue }
            let note = month == 0 ? "Lúc sinh" : month == 6 ? "Khám định kỳ 6 tháng – phát triển tốt" : ""
            baby.measurements.append(BodyMeasurement(date: date, weight: weights[month], height: heights[month], headCircumference: heads[month],
                                                     method: month % 3 == 0 ? "Trạm y tế phường" : "Cân điện tử tại nhà", notes: note))
        }

        let station = "Trạm y tế phường", vnvc = "Phòng tiêm VNVC", maternity = "BV Phụ sản Hà Nội"
        let fiveInOne = "5 trong 1 (Bạch hầu – Ho gà – Uốn ván – Viêm gan B – Hib)"
        baby.vaccinations = [
            vaccination("Viêm gan B (sơ sinh)", dose: 1, at: birth.addingTimeInterval(6 * 3600), clinic: maternity),
            vaccination("Lao (BCG)", dose: 1, at: days(3, after: birth), clinic: maternity, notes: "Có sẹo nhỏ sau 6 tuần"),
            vaccination(fiveInOne, dose: 1, at: months(2, after: birth), clinic: station),
            vaccination(fiveInOne, dose: 2, at: months(3, after: birth), clinic: station),
            vaccination(fiveInOne, dose: 3, at: months(4, after: birth, days: 2), clinic: station,
                        next: months(18, after: birth), remind: true),
            vaccination("Bại liệt uống (OPV)", dose: 1, at: months(2, after: birth), clinic: station),
            vaccination("Bại liệt uống (OPV)", dose: 2, at: months(3, after: birth), clinic: station),
            vaccination("Bại liệt uống (OPV)", dose: 3, at: months(4, after: birth, days: 2), clinic: station),
            vaccination("Rota (uống)", dose: 1, at: months(2, after: birth, days: 5), clinic: vnvc),
            vaccination("Rota (uống)", dose: 2, at: months(3, after: birth, days: 5), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 1, at: months(2, after: birth, days: 5), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 2, at: months(4, after: birth, days: 5), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 3, at: months(6, after: birth, days: 5), clinic: vnvc,
                        notes: "Mũi nhắc lúc 12 tháng", next: months(12, after: birth), remind: true),
            vaccination("Sởi", dose: 1, at: months(9, after: birth), clinic: station, next: months(18, after: birth), remind: true),
            vaccination("Cúm", dose: 1, at: months(6, after: birth, days: 10), clinic: vnvc,
                        notes: "Mũi 2 cách 1 tháng", next: months(7, after: birth, days: 10))
        ].compactMap { $0 }

        baby.medicationReminders = [
            MedicationReminder(name: "Paracetamol", amount: "5", unit: "ml", nextDate: now.addingTimeInterval(105 * 60),
                               note: "Chỉ dùng nếu sốt ≥ 38,5°C, cách lần trước ít nhất 4–6 giờ", enabled: true, episodeOnly: true),
            MedicationReminder(name: "Siro ho Prospan", amount: "2,5", unit: "ml", nextDate: now.addingTimeInterval(6 * 3600),
                               note: "Tạm dừng khi bé hết ho", enabled: false, episodeOnly: true),
            MedicationReminder(name: "Vitamin D3", amount: "1", unit: "giọt", nextDate: at(-1, 8, 0),
                               note: "Mỗi sáng sau cữ bú đầu", enabled: true, episodeOnly: false)
        ]
        baby.isTrackingIllness = true
        baby.illnessTitle = "Sốt, viêm họng"
        baby.illnessStartDate = calendar.startOfDay(for: hoursAgo(52))
        finish(&baby)
        return baby
    }

    mutating func routineAn(days: Int, illnessDays: Int) -> [CareActivity] {
        var list: [CareActivity] = []
        let meals = ["Cháo thịt bằm, bí đỏ", "Bột ăn dặm rau củ", "Cháo cá hồi, cà rốt", "Súp khoai tây, thịt gà", "Cháo tôm, rau ngót"]
        let snacks = ["Chuối nghiền", "Sữa chua", "Bơ dầm", "Táo hấp nghiền"]
        let play = ["Tummy time 15 phút", "Đi dạo công viên", "Chơi xếp hình với bố", "Nghe nhạc, tập vỗ tay"]
        for d in 0..<days {
            let sick = d < illnessDays
            for (hour, minute) in [(6, 30), (10, 0), (13, 30), (17, 0), (20, 0)] {
                let amount = sick ? int(80...120) : int(130...180)
                add(CareActivity(kind: .milk, date: jitter(at(d, hour, minute), minutes: 20), value: "\(amount)", unit: "ml",
                                 note: sick && amount < 100 ? "Bú ít hơn thường ngày" : "",
                                 detail: pick(["Sữa công thức", "Bú mẹ", "Sữa mẹ vắt"])), to: &list)
            }
            add(CareActivity(kind: .meal, date: jitter(at(d, 8, 30), minutes: 15), value: pick(meals), unit: sick ? "1/2 bát" : "1 bát"), to: &list)
            add(CareActivity(kind: .meal, date: jitter(at(d, 15, 30), minutes: 15), value: pick(snacks)), to: &list)
            add(CareActivity(kind: .water, date: jitter(at(d, 11, 0), minutes: 30), value: "\(int(30...60))", unit: "ml"), to: &list)
            add(CareActivity(kind: .sleep, date: jitter(at(d, 9, 30), minutes: 20), value: "\(int(60...90))", unit: "phút"), to: &list)
            add(CareActivity(kind: .sleep, date: jitter(at(d, 14, 30), minutes: 20), value: "\(int(75...110))", unit: "phút"), to: &list)
            // The night sleep starts the evening before and belongs to that day's diary.
            add(CareActivity(kind: .sleep, date: jitter(at(d + 1, 20, 30), minutes: 15), value: "\(int(560...620))", unit: "phút",
                             note: sick ? "Trằn trọc, dậy 2 lần" : ""), to: &list)
            for (hour, minute, content) in [(7, 0, "Đi tiểu"), (9, 30, "Đi ngoài"), (12, 0, "Thay tã"), (15, 0, "Đi tiểu"), (18, 40, "Cả hai"), (21, 15, "Thay tã")] {
                add(CareActivity(kind: .diaper, date: jitter(at(d, hour, minute), minutes: 25), value: content), to: &list)
            }
            add(CareActivity(kind: .bath, date: jitter(at(d, 18, 15), minutes: 10), value: "Tắm nước ấm",
                             note: pick(["", "Bé thích nghịch nước", "", "Lau khô kỹ sau tai"])), to: &list)
            if d % 3 == 0 && !sick {
                add(CareActivity(kind: .other, date: jitter(at(d, 16, 30), minutes: 30), value: pick(play)), to: &list)
            }
        }
        return list
    }

    func episodeAn() -> [CareActivity] {
        var list: [CareActivity] = []
        let readings: [(hours: Double, value: String, site: String)] = [
            (52, "37,9", "Nách · Điện tử"), (48, "38,4", "Nách · Điện tử"), (44, "38,1", "Tai"), (40, "38,6", "Nách · Điện tử"), (34, "37,8", "Trán"),
            (29, "38,2", "Nách · Điện tử"), (24, "38,5", "Nách · Điện tử"), (19.5, "37,9", "Tai"), (14, "37,6", "Nách · Điện tử"), (8, "37,5", "Nách · Điện tử"), (2.5, "37,3", "Nách · Điện tử")
        ]
        for reading in readings {
            add(CareActivity(kind: .temperature, date: hoursAgo(reading.hours), value: reading.value, unit: "°C",
                             note: reading.hours == 40 ? "Sốt cao về đêm, bé quấy" : "", detail: reading.site), to: &list)
        }
        for hours in [47.8, 39.8, 23.8] {
            add(CareActivity(kind: .medicine, date: hoursAgo(hours), value: "5", unit: "ml", note: "Hạ sốt sau khoảng 40 phút", detail: "Paracetamol"), to: &list)
        }
        for hours in [37.0, 27.0, 13.0] {
            add(CareActivity(kind: .medicine, date: hoursAgo(hours), value: "2,5", unit: "ml", detail: "Siro ho Prospan"), to: &list)
        }
        add(CareActivity(kind: .symptom, date: hoursAgo(51), value: "Sốt (dưới 24 giờ), Ho (khan), Sổ mũi (nước trong)", note: "Ho nhẹ, chảy mũi trong"), to: &list)
        add(CareActivity(kind: .symptom, date: hoursAgo(38), value: "Sốt (1–2 ngày), Ho (có đờm), Mệt (quấy khóc)", note: "Ho nhiều hơn về đêm, bỏ chơi"), to: &list)
        add(CareActivity(kind: .symptom, date: hoursAgo(12), value: "Ho (có đờm)", note: "Đỡ hơn, còn ho khi ngủ"), to: &list)
        for (hours, rate) in [(39.5, "46"), (25.5, "42"), (13.5, "36")] {
            add(CareActivity(kind: .breathing, date: hoursAgo(hours), value: rate, unit: "lần/phút", detail: "Lúc ngủ"), to: &list)
        }
        add(CareActivity(kind: .doctor, date: hoursAgo(36), value: "Sốt cao, ho về đêm", unit: "Viêm họng cấp", note: "BS Lan – Phòng khám Nhi Đức Tâm",
                         detail: "Paracetamol 5 ml khi sốt ≥ 38,5°C, cách tối thiểu 4–6 giờ; siro ho 2,5 ml × 2 lần/ngày. Tái khám sớm nếu sốt quá 3 ngày.",
                         attachments: [CarePreviewImages.photo("Đơn thuốc", emoji: "💊", hue: 0.55)].compactMap { $0 },
                         followUpDate: calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: hoursAgo(-80)))), to: &list)
        return list
    }

    // MARK: Bé Minh · 3 years, nap in progress

    mutating func minh() -> BabyData {
        let birth = months(-38, after: now, days: -5)
        floor = birth
        var profile = BabyProfile(name: "Bé Minh", birthDate: birth, gender: .boy, bloodType: "A",
                                  healthNotes: "Đi học mẫu giáo cả ngày, ngủ trưa 12:30. Hay quên uống nước – nhắc 3 lần/ngày.",
                                  medicalHistory: "Sốt xuất huyết lúc 2 tuổi, nằm viện 5 ngày. Đã mổ thoát vị bẹn lúc 18 tháng.")
        profile.avatarData = CarePreviewImages.avatar(emoji: "👦", hue: 0.58)
        var baby = BabyData(profile: profile)

        var list: [CareActivity] = []
        let breakfasts = ["Bún bò", "Phở gà", "Bánh mì trứng", "Cháo lươn", "Xôi gấc"]
        let mains = ["Cơm, cá kho, canh rau", "Cơm, thịt kho trứng, canh bí", "Cơm, tôm rim, súp lơ", "Mì Ý sốt bò", "Cơm, gà rang gừng, canh cải"]
        for d in 0..<21 {
            add(CareActivity(kind: .meal, date: jitter(at(d, 7, 15), minutes: 10), value: pick(breakfasts)), to: &list)
            add(CareActivity(kind: .meal, date: jitter(at(d, 11, 30), minutes: 15), value: pick(mains), note: isWeekend(day(d)) ? "" : "Ăn ở lớp"), to: &list)
            add(CareActivity(kind: .meal, date: jitter(at(d, 18, 0), minutes: 15), value: pick(mains)), to: &list)
            add(CareActivity(kind: .milk, date: jitter(at(d, 21, 0), minutes: 10), value: "180", unit: "ml", detail: "Sữa công thức"), to: &list)
            for (hour, minute) in [(9, 0), (14, 0), (16, 30)] {
                add(CareActivity(kind: .water, date: jitter(at(d, hour, minute), minutes: 20), value: "\(int(80...150))", unit: "ml"), to: &list)
            }
            add(CareActivity(kind: .sleep, date: jitter(at(d + 1, 21, 0), minutes: 15), value: "\(int(560...600))", unit: "phút"), to: &list)
            add(CareActivity(kind: .sleep, date: jitter(at(d, 12, 30), minutes: 10), value: "\(int(80...100))", unit: "phút"), to: &list)
            add(CareActivity(kind: .diaper, date: jitter(at(d, 8, 0), minutes: 20), value: "Đi ngoài"), to: &list)
            add(CareActivity(kind: .bath, date: jitter(at(d, 19, 0), minutes: 10), value: "Tắm nước ấm"), to: &list)
            if !isWeekend(day(d)) { add(CareActivity(kind: .other, date: at(d, 8, 0), value: "Đi học mẫu giáo"), to: &list) }
            if calendar.component(.weekday, from: day(d)) == 7 {
                add(CareActivity(kind: .other, date: at(d, 9, 30), value: "Học bơi 45 phút", note: "Đã bơi được 5 m không phao"), to: &list)
            }
        }
        add(CareActivity(kind: .doctor, date: at(10, 9, 30), value: "Khám răng định kỳ",
                         note: "Nha khoa Nhi – men răng tốt, hướng dẫn chải răng 2 lần/ngày. Hẹn lại sau 6 tháng."), to: &list)
        add(CareActivity(kind: .temperature, date: at(16, 20, 0), value: "37,2", unit: "°C", note: "Kiểm tra sau khi đi học về", detail: "Trán"), to: &list)
        add(CareActivity(kind: .symptom, date: at(16, 19, 30), value: "Sổ mũi", note: "Thay đổi thời tiết, hết sau 2 ngày"), to: &list)
        add(CareActivity(kind: .other, date: at(5, 16, 30), value: "Đi công viên Thống Nhất", note: "Chơi cầu trượt, đạp xe thăng bằng",
                         attachments: [CarePreviewImages.photo("Công viên", emoji: "🛝", hue: 0.33), CarePreviewImages.photo("Đạp xe", emoji: "🚲", hue: 0.12)].compactMap { $0 }), to: &list)
        baby.activities = list

        let weights = [3.3, 6.4, 7.9, 8.9, 9.6, 10.3, 10.9, 11.5, 12.2, 12.7, 13.3, 13.8, 14.3]
        let heights = [49.9, 61.4, 67.6, 72.0, 75.7, 79.1, 82.3, 85.1, 87.8, 90.2, 92.4, 94.5, 96.1]
        for (index, month) in stride(from: 0, through: 36, by: 3).enumerated() {
            let date = month == 0 ? birth : months(month, after: birth, days: int(0...5))
            baby.measurements.append(BodyMeasurement(date: date, weight: weights[index], height: heights[index],
                                                     headCircumference: month <= 24 ? 34.5 + Double(month) * 0.5 : nil,
                                                     method: month % 12 == 0 ? "Khám định kỳ" : "Cân tại nhà"))
        }
        baby.measurements.append(BodyMeasurement(date: at(4, 19, 30), weight: 14.6, height: 97.2, method: "Cân tại nhà"))

        let station = "Trạm y tế phường", vnvc = "Phòng tiêm VNVC", maternity = "BV Phụ sản Trung ương"
        let fiveInOne = "5 trong 1 (Bạch hầu – Ho gà – Uốn ván – Viêm gan B – Hib)"
        baby.vaccinations = [
            vaccination("Viêm gan B (sơ sinh)", dose: 1, at: birth.addingTimeInterval(8 * 3600), clinic: maternity),
            vaccination("Lao (BCG)", dose: 1, at: days(2, after: birth), clinic: maternity),
            vaccination(fiveInOne, dose: 1, at: months(2, after: birth), clinic: station),
            vaccination(fiveInOne, dose: 2, at: months(3, after: birth), clinic: station),
            vaccination(fiveInOne, dose: 3, at: months(4, after: birth), clinic: station),
            vaccination(fiveInOne, dose: 4, at: months(18, after: birth, days: 4), clinic: station, notes: "Mũi nhắc lại"),
            vaccination("Bại liệt uống (OPV)", dose: 1, at: months(2, after: birth), clinic: station),
            vaccination("Bại liệt uống (OPV)", dose: 2, at: months(3, after: birth), clinic: station),
            vaccination("Bại liệt uống (OPV)", dose: 3, at: months(4, after: birth), clinic: station),
            vaccination("Bại liệt tiêm (IPV)", dose: 1, at: months(5, after: birth), clinic: station),
            vaccination("Rota (uống)", dose: 1, at: months(2, after: birth, days: 3), clinic: vnvc),
            vaccination("Rota (uống)", dose: 2, at: months(3, after: birth, days: 3), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 1, at: months(2, after: birth, days: 3), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 2, at: months(4, after: birth, days: 3), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 3, at: months(6, after: birth, days: 3), clinic: vnvc),
            vaccination("Phế cầu (PCV)", dose: 4, at: months(12, after: birth, days: 6), clinic: vnvc, notes: "Mũi nhắc lại"),
            vaccination("Sởi", dose: 1, at: months(9, after: birth), clinic: station),
            vaccination("Sởi – Quai bị – Rubella (MMR)", dose: 1, at: months(12, after: birth, days: 6), clinic: vnvc),
            vaccination("Sởi – Quai bị – Rubella (MMR)", dose: 2, at: months(18, after: birth, days: 4), clinic: vnvc, next: months(60, after: birth)),
            vaccination("Viêm não Nhật Bản", dose: 1, at: months(12, after: birth, days: 20), clinic: station),
            vaccination("Viêm não Nhật Bản", dose: 2, at: months(13, after: birth, days: 6), clinic: station),
            vaccination("Viêm não Nhật Bản", dose: 3, at: months(24, after: birth, days: 20), clinic: station, next: months(60, after: birth)),
            vaccination("Thủy đậu", dose: 1, at: months(13, after: birth), clinic: vnvc),
            vaccination("Viêm gan A", dose: 1, at: months(12, after: birth, days: 20), clinic: vnvc),
            vaccination("Viêm gan A", dose: 2, at: months(18, after: birth, days: 20), clinic: vnvc),
            vaccination("Cúm", dose: 3, at: months(26, after: birth), clinic: vnvc, notes: "Nhắc lại hàng năm",
                        next: days(14, after: now), remind: true)
        ].compactMap { $0 }

        baby.medicationReminders = [
            MedicationReminder(name: "Siro bổ sung kẽm", amount: "5", unit: "ml", nextDate: at(-1, 19, 30),
                               note: "Sau bữa tối, đợt 1 tháng theo chỉ định", enabled: true, episodeOnly: false)
        ]
        baby.sleepStartDate = now.addingTimeInterval(-35 * 60)
        finish(&baby)
        return baby
    }

    // MARK: Bé Bơ · 12 days old, newborn rhythm

    mutating func bo() -> BabyData {
        let birth = calendar.date(bySettingHour: 4, minute: 20, second: 0, of: day(12)) ?? day(12)
        floor = birth
        var profile = BabyProfile(name: "Bé Bơ", birthDate: birth, gender: .girl, bloodType: "Chưa rõ",
                                  healthNotes: "Sinh thường 3,1 kg. Bú mẹ hoàn toàn, cữ 3 giờ. Rốn đã rụng ngày 9.")
        profile.avatarData = CarePreviewImages.avatar(emoji: "👶", hue: 0.08)
        var baby = BabyData(profile: profile)

        var list: [CareActivity] = []
        let diaperCycle = ["Đi tiểu", "Cả hai", "Đi tiểu", "Đi ngoài", "Đi tiểu", "Cả hai", "Đi tiểu", "Thay tã"]
        for d in 0...12 {
            for (index, hour) in stride(from: 0, through: 21, by: 3).enumerated() {
                add(CareActivity(kind: .milk, date: at(d, hour, int(0...25)), value: "\(int(50...90))", unit: "ml",
                                 detail: index % 4 == 1 ? "Sữa mẹ vắt" : "Bú mẹ"), to: &list)
                add(CareActivity(kind: .sleep, date: at(d, hour + 1, int(0...20)), value: "\(int(80...125))", unit: "phút"), to: &list)
                add(CareActivity(kind: .diaper, date: at(d, hour + 2, int(0...30)), value: diaperCycle[index]), to: &list)
            }
            add(CareActivity(kind: .bath, date: jitter(at(d, 10, 0), minutes: 15), value: d >= 4 ? "Tắm + vệ sinh rốn" : "Tắm nước ấm"), to: &list)
            add(CareActivity(kind: .medicine, date: jitter(at(d, 8, 0), minutes: 10), value: "1", unit: "giọt", detail: "Vitamin D3"), to: &list)
        }
        add(CareActivity(kind: .temperature, date: at(3, 20, 0), value: "36,8", unit: "°C", detail: "Nách"), to: &list)
        add(CareActivity(kind: .symptom, date: at(7, 8, 30), value: "Khác", note: "Phơi nắng sáng 15 phút theo hướng dẫn", detail: "Vàng da nhẹ vùng mặt"), to: &list)
        add(CareActivity(kind: .doctor, date: at(6, 9, 0), value: "Tái khám vàng da sinh lý", note: "Bilirubin trong ngưỡng, không cần chiếu đèn. Theo dõi thêm tại nhà."), to: &list)
        baby.activities = list

        baby.measurements = [
            BodyMeasurement(date: birth, weight: 3.1, height: 49, headCircumference: 33.5, method: "Bệnh viện", notes: "Lúc sinh"),
            BodyMeasurement(date: at(7, 9, 0), weight: 3.0, method: "Cân tại nhà", notes: "Sụt cân sinh lý"),
            BodyMeasurement(date: at(1, 9, 0), weight: 3.25, height: 50, headCircumference: 34, method: "Trạm y tế", notes: "Đã lấy lại cân nặng lúc sinh")
        ]
        let maternity = "BV Phụ sản Trung ương"
        baby.vaccinations = [
            vaccination("Viêm gan B (sơ sinh)", dose: 1, at: birth.addingTimeInterval(6 * 3600), clinic: maternity,
                        notes: "Mũi 2 nằm trong 5 trong 1 lúc 2 tháng", next: months(2, after: birth), remind: true),
            vaccination("Lao (BCG)", dose: 1, at: at(11, 9, 0), clinic: maternity)
        ].compactMap { $0 }
        baby.medicationReminders = [
            MedicationReminder(name: "Vitamin D3", amount: "1", unit: "giọt", nextDate: at(-1, 8, 0), note: "Mỗi sáng", enabled: true, episodeOnly: false)
        ]
        finish(&baby)
        return baby
    }
}

/// Small generated pictures so photo galleries and avatars have something to show without bundling assets.
private nonisolated enum CarePreviewImages {
    static func avatar(emoji: String, hue: CGFloat) -> Data? { render(size: CGSize(width: 320, height: 320), emoji: emoji, emojiSize: 170, caption: nil, hue: hue) }
    static func photo(_ caption: String, emoji: String, hue: CGFloat) -> Data? { render(size: CGSize(width: 640, height: 480), emoji: emoji, emojiSize: 150, caption: caption, hue: hue) }

    private static func render(size: CGSize, emoji: String, emojiSize: CGFloat, caption: String?, hue: CGFloat) -> Data? {
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor(hue: hue, saturation: 0.35, brightness: 0.98, alpha: 1).cgColor,
                          UIColor(hue: hue, saturation: 0.55, brightness: 0.78, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let emojiAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: emojiSize), .paragraphStyle: paragraph]
            let emojiHeight = emojiSize * 1.25
            let emojiTop = caption == nil ? (size.height - emojiHeight) / 2 : size.height * 0.16
            (emoji as NSString).draw(in: CGRect(x: 0, y: emojiTop, width: size.width, height: emojiHeight), withAttributes: emojiAttributes)
            if let caption {
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
                shadow.shadowBlurRadius = 6
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph, .shadow: shadow
                ]
                ("Ảnh mẫu · \(caption)" as NSString).draw(in: CGRect(x: 24, y: size.height * 0.74, width: size.width - 48, height: 60), withAttributes: captionAttributes)
            }
        }.jpegData(compressionQuality: 0.7)
        #else
        return nil
        #endif
    }
}
