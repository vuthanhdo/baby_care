import Foundation
import WidgetKit

/// Leaves the selected baby's last feed, diaper and sleep in the App Group for the Quick log widget once the
/// view model holds a committed snapshot, and removes them when the session ends. Like reminders, an effect
/// after the data is saved, never part of a View.
@MainActor struct CareWidgetPublisher {
    var defaults: UserDefaults? = QuickLogStore.defaults

    func publish(_ database: CareDatabase, canWrite: Bool) {
        write(Self.snapshot(of: database, canWrite: canWrite, language: AppLanguage.current.rawValue))
    }

    func clear() { write(nil) }

    /// A widget tap that did not save says why on the widget, which cannot show an alert.
    func show(notice: String, at date: Date = Date()) {
        guard var snapshot = QuickLogStore.read(from: defaults) else { return }
        snapshot.notice = notice; snapshot.noticeDate = date
        write(snapshot)
    }

    nonisolated static func snapshot(of database: CareDatabase, canWrite: Bool, language: String) -> QuickLogSnapshot? {
        guard database.hasOnboarded, let baby = database.selectedBaby else { return nil }
        let milk = baby.activities.first { $0.kind == .milk }
        return QuickLogSnapshot(babyName: baby.profile.name, language: language, canWrite: canWrite,
                                lastDiaper: baby.activities.first { $0.kind == .diaper }?.date,
                                lastMilk: milk?.date, milkAmount: milk?.formattedValue, sleepStart: baby.sleepStartDate)
    }

    private func write(_ snapshot: QuickLogSnapshot?) {
        if QuickLogStore.write(snapshot, to: defaults) { WidgetCenter.shared.reloadTimelines(ofKind: QuickLogStore.widgetKind) }
    }
}
