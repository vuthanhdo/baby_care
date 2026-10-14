import Foundation
import Testing
@testable import BabyCare

@MainActor
struct InsightDaySummaryTests {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))! }
    private var start: Date { calendar.startOfDay(for: day) }
    private func at(_ hours: Double) -> Date { start.addingTimeInterval(hours * 3600) }

    @Test func aggregatesOnlyTheGivenDay() {
        let activities = [
            CareActivity(kind: .milk, date: at(8), value: "120", unit: "ml", detail: "Sữa công thức"),
            CareActivity(kind: .milk, date: at(11), value: "15", unit: "phút", detail: "Bú mẹ"),
            CareActivity(kind: .milk, date: at(13), value: "abc", unit: "ml"),
            CareActivity(kind: .water, date: at(10), value: "50", unit: "ml"),
            CareActivity(kind: .diaper, date: at(7), value: "Đi tiểu"),
            CareActivity(kind: .diaper, date: at(15), value: "Cả hai"),
            CareActivity(kind: .meal, date: at(12), value: "Cháo"),
            CareActivity(kind: .medicine, date: at(9), value: "5", unit: "ml", detail: "Hạ sốt"),
            CareActivity(kind: .sleep, date: at(14), value: "90", unit: "phút"),
            CareActivity(kind: .milk, date: start.addingTimeInterval(-60), value: "100", unit: "ml"),
            CareActivity(kind: .diaper, date: at(24), value: "Thay tã")
        ]
        let summary = InsightData.daySummary(activities, on: day, calendar: calendar)
        #expect(summary.feedCount == 3)
        #expect(summary.bottleMilliliters == 120)
        #expect(summary.breastfeedMinutes == 15)
        #expect(summary.waterMilliliters == 50)
        #expect(summary.diaperCount == 2)
        #expect(summary.lastDiaper == at(15))
        #expect(summary.mealCount == 1)
        #expect(summary.medicineCount == 1)
        #expect(summary.sleepCount == 1)
        #expect(summary.sleepHours == 1.5)
        #expect(!summary.isEmpty)
    }

    @Test func sleepCountsPartialOverlapAndIgnoresUnusableValues() {
        let activities = [
            CareActivity(kind: .sleep, date: start.addingTimeInterval(-1800), value: "60", unit: "phút"),
            CareActivity(kind: .sleep, date: at(23), value: "2", unit: "giờ"),
            CareActivity(kind: .sleep, date: at(10), value: "0", unit: "phút"),
            CareActivity(kind: .sleep, date: at(11), value: "nan", unit: "phút"),
            CareActivity(kind: .sleep, date: start.addingTimeInterval(-7200), value: "30", unit: "phút")
        ]
        let summary = InsightData.daySummary(activities, on: day, calendar: calendar)
        #expect(summary.sleepCount == 2)
        let hours = try! #require(summary.sleepHours)
        #expect(abs(hours - 1.5) < 1e-9)
        let interval = DateInterval(start: start, end: at(24))
        #expect(InsightData.sleepHours(activities, in: interval) == summary.sleepHours)
    }

    @Test func emptyDiaryAndOverflowedTotals() {
        #expect(InsightData.daySummary([], on: day, calendar: calendar) == InsightDaySummary())
        #expect(InsightData.daySummary([], on: day, calendar: calendar).isEmpty)
        let huge = [
            CareActivity(kind: .milk, date: at(8), value: "1e308", unit: "ml"),
            CareActivity(kind: .milk, date: at(9), value: "1e308", unit: "ml")
        ]
        let summary = InsightData.daySummary(huge, on: day, calendar: calendar)
        #expect(summary.feedCount == 2)
        #expect(summary.bottleMilliliters == nil)
    }
}
