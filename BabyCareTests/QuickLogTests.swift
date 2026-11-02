import Foundation
import Testing
@testable import BabyCare

@MainActor
struct QuickLogTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func baby(_ activities: [CareActivity] = [], sleepStart: Date? = nil) -> BabyData {
        BabyData(profile: BabyProfile(name: "Bé Sóc", birthDate: now.addingTimeInterval(-200 * 86_400)), activities: activities, sleepStartDate: sleepStart)
    }

    private func entry(_ plan: QuickLogPlanner.Plan) -> (CareActivity, Date?)? {
        guard case .saveActivities(_, let entries, let finishing, _) = plan.mutation, entries.count == 1 else { return nil }
        return (entries[0], finishing)
    }

    @Test func diaperButtonLogsAChangeNow() throws {
        let plan = try QuickLogPlanner.plan(.diaper, baby: baby(), now: now)
        let (saved, _) = try #require(entry(plan))
        #expect(saved.kind == .diaper && saved.value == "Thay tã" && saved.date == now)
    }

    @Test func milkButtonRepeatsTheLastFeed() throws {
        let last = CareActivity(kind: .milk, date: now.addingTimeInterval(-3 * 3600), value: "120", unit: "ml", note: "Bé bú chậm", detail: "Sữa mẹ vắt")
        let older = CareActivity(kind: .milk, date: now.addingTimeInterval(-6 * 3600), value: "90", unit: "ml", detail: "Sữa công thức")
        let plan = try QuickLogPlanner.plan(.milk, baby: baby([last, older]), now: now)
        let (saved, _) = try #require(entry(plan))
        #expect(saved.id != last.id && saved.date == now)
        #expect(saved.value == "120" && saved.unit == "ml" && saved.detail == "Sữa mẹ vắt")
        #expect(saved.note.isEmpty) // a note belongs to that one feed
    }

    @Test func milkButtonNeedsAFeedToRepeat() {
        #expect(throws: CareDataError.self) { try QuickLogPlanner.plan(.milk, baby: baby(), now: now) }
    }

    @Test func sleepButtonStartsThenEndsTheSleep() throws {
        let awake = baby()
        let start = try QuickLogPlanner.plan(.sleep, baby: awake, now: now)
        #expect(start.mutation == .startSleep(babyID: awake.profile.id, date: now))

        let began = now.addingTimeInterval(-(95 * 60 + 40))
        let end = try QuickLogPlanner.plan(.sleep, baby: baby(sleepStart: began), now: now)
        let (saved, finishing) = try #require(entry(end))
        #expect(saved.kind == .sleep && saved.date == began && saved.value == "95" && saved.unit == "phút")
        #expect(finishing == began) // clears the running sleep in the same commit
    }

    @Test func endingTheSleepThroughTheReducerClearsTheTimer() throws {
        let began = Date().addingTimeInterval(-30 * 60)
        var database = CareDatabase(babies: [baby(sleepStart: began)], hasOnboarded: true)
        database.selectedBabyID = database.babies[0].profile.id
        let plan = try QuickLogPlanner.plan(.sleep, baby: database.babies[0], now: Date())
        let next = try database.applying(plan.mutation)
        #expect(next.babies[0].sleepStartDate == nil)
        #expect(next.babies[0].activities.first?.kind == .sleep)
    }

    @Test func formAsksForAPositiveAmount() {
        for amount in [nil, 0, -5, .infinity] as [Double?] {
            #expect(throws: CareDataError.self) { try QuickLogPlanner.plan(.milk, amount: amount, content: nil, note: nil, baby: baby(), now: now) }
        }
    }

    @Test func formBuildsEntriesLikeTheActivityForm() throws {
        let breast = CareActivity(kind: .milk, date: now.addingTimeInterval(-3600), value: "15", unit: "phút", detail: "Bú mẹ")
        let bottle = CareActivity(kind: .milk, date: now.addingTimeInterval(-7200), value: "100", unit: "ml", detail: "Sữa mẹ vắt")
        let milk = try #require(entry(try QuickLogPlanner.plan(.milk, amount: 130, content: nil, note: " đêm ", baby: baby([breast, bottle]), now: now))).0
        #expect(milk.value == "130" && milk.unit == "ml" && milk.detail == "Sữa mẹ vắt" && milk.note == "đêm")

        let temperature = try #require(entry(try QuickLogPlanner.plan(.temperature, amount: 37.5, content: nil, note: nil, baby: baby(), now: now))).0
        #expect(temperature.unit == "°C" && temperature.detail == "Chưa rõ" && temperature.numericValue == 37.5)

        let diaper = try #require(entry(try QuickLogPlanner.plan(.diaper, amount: nil, content: "Đi ngoài", note: nil, baby: baby(), now: now))).0
        #expect(diaper.value == "Đi ngoài")

        let bath = try #require(entry(try QuickLogPlanner.plan(.bath, amount: nil, content: nil, note: nil, baby: baby(), now: now))).0
        #expect(bath.value == CareActivity.recordedValue)

        #expect(throws: CareDataError.self) { try QuickLogPlanner.plan(.other, amount: nil, content: "  ", note: nil, baby: baby(), now: now) }
    }

    @Test func snapshotShowsTheSelectedBabysLatestEntries() throws {
        let diaper = CareActivity(kind: .diaper, date: now.addingTimeInterval(-600), value: "Đi tiểu")
        let milk = CareActivity(kind: .milk, date: now.addingTimeInterval(-1800), value: "120", unit: "ml", detail: "Sữa công thức")
        let other = BabyData(profile: BabyProfile(name: "Bé Na"), activities: [CareActivity(kind: .milk, date: now, value: "60", unit: "ml")])
        let selected = baby([diaper, milk], sleepStart: now.addingTimeInterval(-300))
        var database = CareDatabase(babies: [other, selected], hasOnboarded: true)
        database.selectedBabyID = selected.profile.id

        let snapshot = try #require(CareWidgetPublisher.snapshot(of: database, canWrite: false, language: "vi"))
        #expect(snapshot.babyName == "Bé Sóc" && !snapshot.canWrite && snapshot.language == "vi")
        #expect(snapshot.lastDiaper == diaper.date && snapshot.lastMilk == milk.date && snapshot.milkAmount == milk.formattedValue)
        #expect(snapshot.sleepStart == selected.sleepStartDate)
        #expect(CareWidgetPublisher.snapshot(of: CareDatabase(), canWrite: true, language: "vi") == nil)
    }

    @Test func storeSkipsUnchangedSnapshotsAndClears() throws {
        let suite = "BabyCare.QuickLogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshot = QuickLogSnapshot(babyName: "Bé Sóc", language: "en", canWrite: true)
        #expect(QuickLogStore.write(snapshot, to: defaults))
        #expect(!QuickLogStore.write(snapshot, to: defaults)) // nothing new, the widget is not reloaded
        #expect(QuickLogStore.read(from: defaults) == snapshot)
        #expect(QuickLogStore.write(nil, to: defaults))
        #expect(QuickLogStore.read(from: defaults) == nil)
    }

    @Test func noticeShowsForAWhile() {
        var snapshot = QuickLogSnapshot(babyName: "Bé Sóc", language: "vi", canWrite: true)
        snapshot.notice = "Không kết nối được cloud"; snapshot.noticeDate = now
        #expect(snapshot.notice(at: now.addingTimeInterval(60)) == "Không kết nối được cloud")
        #expect(snapshot.notice(at: now.addingTimeInterval(QuickLogSnapshot.noticeDuration + 1)) == nil)
    }

    @Test func viewModelPublishesAfterACommit() async throws {
        let suite = "BabyCare.QuickLogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = CarePreviewData.make()
        let model = BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data,
                                      widget: CareWidgetPublisher(defaults: defaults))
        let selected = try #require(data.selectedBaby)
        let plan = try QuickLogPlanner.plan(.diaper, baby: selected)
        #expect(await model.send(.commit(plan.mutation)))
        let snapshot = try #require(QuickLogStore.read(from: defaults))
        #expect(snapshot.babyName == selected.profile.name)
        #expect(snapshot.lastDiaper == model.activities.first { $0.kind == .diaper }?.date)
        await model.deactivate()
        #expect(QuickLogStore.read(from: defaults) == nil) // leaving the session removes the baby from the Home Screen
    }
}
