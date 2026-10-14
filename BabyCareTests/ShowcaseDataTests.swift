import Foundation
import Testing
@testable import BabyCare

/// The showcase dataset must pass the same validation the forms enforce, otherwise edits in the demo fail.
struct ShowcaseDataTests {
    @Test func showcaseIsValidAndCoversEveryFeature() throws {
        let now = Date()
        let data = CarePreviewData.showcase(now: now)
        #expect(data.hasOnboarded)
        #expect(data.babies.count == 3)
        #expect(data.selectedBaby?.profile.name == "Bé An")
        #expect(Set(data.babies.flatMap { $0.activities.map(\.kind) }) == Set(ActivityKind.allCases))

        for baby in data.babies {
            try CareValidation.profile(baby.profile)
            #expect(Set(baby.activities.map(\.id)).count == baby.activities.count)
            #expect(baby.activities == baby.activities.sorted { $0.date > $1.date })
            for entry in baby.activities {
                try CareValidation.activity(entry)
                #expect(entry.date >= baby.profile.birthDate && entry.date <= now)
            }
            for item in baby.measurements { try CareValidation.measurement(item, birthDate: baby.profile.birthDate) }
            for record in baby.vaccinations { try CareValidation.vaccination(record, birthDate: baby.profile.birthDate) }
            for reminder in baby.medicationReminders { try CareValidation.reminder(reminder) }
            #expect(!baby.vaccinations.isEmpty && !baby.measurements.isEmpty && !baby.medicationReminders.isEmpty)
            #expect(baby.profile.avatarData != nil)
        }

        let an = try #require(data.selectedBaby)
        #expect(an.isTrackingIllness && an.illnessStartDate <= now && an.illnessStartDate >= an.profile.birthDate)
        #expect(an.medicationReminders.contains { $0.enabled && $0.episodeOnly })
        #expect(an.medicationReminders.contains { !$0.enabled })
        #expect(data.babies.contains { $0.sleepStartDate != nil })
        #expect(data.babies.flatMap(\.vaccinations).contains { ($0.nextDoseDate ?? now) < now })
        #expect(data.babies.flatMap(\.vaccinations).contains { $0.reminderEnabled && ($0.reminderDate ?? now) > now })
        #expect(data.babies.flatMap(\.activities).contains { !$0.attachments.isEmpty })
    }

    @Test func showcaseIsDeterministic() {
        let now = Date()
        func shape(_ data: CareDatabase) -> [[String]] {
            data.babies.map { baby in baby.activities.map { "\($0.kind.rawValue)|\($0.value)|\($0.detail)|\($0.date.timeIntervalSince1970)" } }
        }
        #expect(shape(CarePreviewData.showcase(now: now)) == shape(CarePreviewData.showcase(now: now)))
    }

    @Test func smallFixtureIsUnchangedForUITests() {
        let data = CarePreviewData.make()
        #expect(data.babies.count == 1 && data.selectedBaby?.profile.name == "Bé An")
        #expect(data.selectedBaby?.vaccinations.isEmpty == true && data.selectedBaby?.medicationReminders.isEmpty == true)
    }
}
