import AppIntents
import Foundation

/// Code compiled into both the app and the widget extension: the one-tap actions, their intents and the
/// summary the app leaves in the App Group for the widget to draw.
nonisolated enum QuickLogAction: String, Sendable {
    case diaper, milk, sleep
}

// One parameterless intent per button. The widget names the intent by its own module's type, which the app
// matches by identifier; an enum parameter would arrive as the widget module's type and fail to decode.
// As `LiveActivityIntent`s the system runs them in the app's process (launched in the background, never brought
// to the screen), so they save through the app's own session and store. The widget extension compiles the same
// types with a `QuickLogPerformer` that is never called.

struct LogDiaperIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Thay tã"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult { await QuickLogPerformer.perform(.diaper); return .result() }
}

struct RepeatMilkIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Sữa như cữ trước"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult { await QuickLogPerformer.perform(.milk); return .result() }
}

struct ToggleSleepIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Ngủ / Thức dậy"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult { await QuickLogPerformer.perform(.sleep); return .result() }
}

/// What the widget shows. Text that depends on the app's language is formatted by the app.
nonisolated struct QuickLogSnapshot: Codable, Sendable, Equatable {
    var babyName: String
    /// The app's language ("vi" or "en"), which may differ from the device's.
    var language: String
    var canWrite: Bool
    var lastDiaper: Date?
    var lastMilk: Date?
    /// The last feed as the app shows it, such as "120 ml"; nil when there is none to repeat.
    var milkAmount: String?
    var sleepStart: Date?
    /// Why the last widget tap did not save, shown for a while.
    var notice: String?
    var noticeDate: Date?

    static let noticeDuration: TimeInterval = 15 * 60
    func notice(at date: Date) -> String? {
        guard let notice, let noticeDate, date.timeIntervalSince(noticeDate) < Self.noticeDuration else { return nil }
        return notice
    }
}

nonisolated enum QuickLogStore {
    static let appGroup = "group.com.vuthanhdo.BabyCare"
    static let widgetKind = "QuickLogWidget"
    private static let key = "quickLog.snapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func read(from defaults: UserDefaults? = defaults) -> QuickLogSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuickLogSnapshot.self, from: data)
    }

    /// Returns false when nothing changed, so the caller can skip reloading the widget.
    @discardableResult
    static func write(_ snapshot: QuickLogSnapshot?, to defaults: UserDefaults? = defaults) -> Bool {
        guard let defaults, read(from: defaults) != snapshot else { return false }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: key) }
        else { defaults.removeObject(forKey: key) }
        return true
    }
}
