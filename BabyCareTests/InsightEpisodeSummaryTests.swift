import Foundation
import Testing
@testable import BabyCare

@MainActor
struct InsightEpisodeSummaryTests {
    private let calendar = Calendar.current
    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 8))! }
    private func at(_ hours: Double) -> Date { start.addingTimeInterval(hours * 3600) }

    @Test func countsOnlyEntriesSinceOnsetAndPicksPeakAndLatestSymptoms() {
        let activities = [
            CareActivity(kind: .temperature, date: at(-2), value: "39,5", unit: "°C"),   // before onset: ignored
            CareActivity(kind: .temperature, date: at(1), value: "38,2", unit: "°C"),
            CareActivity(kind: .temperature, date: at(5), value: "38,2", unit: "°C"),    // same peak later wins
            CareActivity(kind: .temperature, date: at(9), value: "37,6", unit: "°C"),
            CareActivity(kind: .temperature, date: at(10), value: "abc", unit: "°C"),    // unusable: ignored
            CareActivity(kind: .medicine, date: at(2), value: "5", unit: "ml", detail: "Paracetamol"),
            CareActivity(kind: .medicine, date: at(8), value: "5", unit: "ml", detail: "Paracetamol"),
            CareActivity(kind: .symptom, date: at(3), value: "Ho"),
            CareActivity(kind: .symptom, date: at(7), value: "Ho, Sổ mũi"),
            CareActivity(kind: .milk, date: at(4), value: "120", unit: "ml")
        ]
        let summary = InsightData.episodeSummary(activities, since: start, now: at(30), calendar: calendar)
        #expect(summary.days == 2)
        #expect(summary.temperatureCount == 3)
        #expect(summary.peakTemperature?.date == at(5))
        #expect(summary.doseCount == 2)
        #expect(summary.latestSymptoms?.date == at(7))
        #expect(summary.symptomNames == ["Ho", "Sổ mũi"])
    }

    @Test func emptyEpisodeHasDefaultsAndDayOneOnTheStartDay() {
        let summary = InsightData.episodeSummary([], since: start, now: at(2), calendar: calendar)
        #expect(summary == InsightEpisodeSummary())
        #expect(summary.days == 1 && summary.symptomNames.isEmpty && summary.peakTemperature == nil)
        // An onset at 23:00 counts the next morning as day 2.
        let late = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 23))!
        #expect(InsightData.episodeSummary([], since: late, now: late.addingTimeInterval(8 * 3600), calendar: calendar).days == 2)
    }

    @Test func nextDoseOptionsSkipMomentsAlreadyPast() {
        let taken = start
        let options = InsightData.nextDoseOptions(after: taken, now: taken.addingTimeInterval(5 * 3600))
        #expect(options.map(\.hours) == [6, 8, 12])
        #expect(options.first?.date == taken.addingTimeInterval(6 * 3600))
        #expect(InsightData.nextDoseOptions(after: taken, now: taken.addingTimeInterval(13 * 3600)).isEmpty)
    }
}
