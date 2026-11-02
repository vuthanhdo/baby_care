import AppIntents
import SwiftUI
import WidgetKit

/// Home Screen widget: three buttons that log a diaper, the last feed again, or the start or end of a sleep
/// without opening the app. Each button runs its intent (`LogDiaperIntent`…) in the app's process; the app then writes a new
/// `QuickLogSnapshot` and reloads this widget.
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        let text = WidgetText(language: nil)
        return StaticConfiguration(kind: QuickLogStore.widgetKind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(entry: entry).containerBackground(Color("CareBackground"), for: .widget)
        }
        .configurationDisplayName(Text(verbatim: text.quickLog))
        .description(Text(verbatim: text.widgetDescription))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

nonisolated struct QuickLogEntry: TimelineEntry {
    var date: Date
    var snapshot: QuickLogSnapshot?
}

nonisolated struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry { QuickLogEntry(date: Date(), snapshot: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        let stored = QuickLogStore.read()
        completion(QuickLogEntry(date: Date(), snapshot: context.isPreview ? stored ?? .sample : stored))
    }

    /// The app reloads the widget whenever the data changes; the only scheduled change is a notice expiring.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        let now = Date()
        let snapshot = QuickLogStore.read()
        var entries = [QuickLogEntry(date: now, snapshot: snapshot)]
        if snapshot?.notice(at: now) != nil, let noticeDate = snapshot?.noticeDate {
            entries.append(QuickLogEntry(date: noticeDate.addingTimeInterval(QuickLogSnapshot.noticeDuration), snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct QuickLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickLogEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot, text: WidgetText(language: snapshot.language))
                .environment(\.locale, Locale(identifier: snapshot.language == "vi" ? "vi_VN" : "en_US"))
        } else {
            let text = WidgetText(language: nil)
            VStack(alignment: .leading, spacing: 6) {
                Label(text.appName, systemImage: "heart.text.square").font(.headline).foregroundStyle(Color("AccentColor"))
                Spacer(minLength: 0)
                Text(verbatim: text.openToStart).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func content(_ snapshot: QuickLogSnapshot, text: WidgetText) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack(spacing: 6) {
                Text(verbatim: snapshot.babyName).font(.headline).lineLimit(1)
                Spacer(minLength: 0)
                if !snapshot.canWrite { Text(verbatim: text.viewOnly).font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
            }
            if let notice = snapshot.notice(at: entry.date) {
                Text(verbatim: notice).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
            if family == .systemSmall {
                VStack(spacing: 6) { buttons(snapshot, text: text) }
            } else {
                HStack(spacing: 8) { buttons(snapshot, text: text) }
            }
        }
    }

    @ViewBuilder private func buttons(_ snapshot: QuickLogSnapshot, text: WidgetText) -> some View {
        tile(.diaper, snapshot: snapshot, title: text.diaper, icon: "figure.child", color: Color("CareRoutine"),
             background: Color("CareRoutineBackground"), enabled: true) { since(snapshot.lastDiaper, text: text) }
        tile(.milk, snapshot: snapshot, title: snapshot.milkAmount.map { "\(text.milk) \($0)" } ?? text.milk, icon: "waterbottle.fill",
             color: Color("CareFeeding"), background: Color("CareFeedingBackground"), enabled: snapshot.milkAmount != nil) {
            if snapshot.milkAmount == nil { Text(verbatim: text.logInApp) } else { since(snapshot.lastMilk, text: text) }
        }
        if let start = snapshot.sleepStart {
            tile(.sleep, snapshot: snapshot, title: text.wakeUp, icon: "sun.max.fill", color: Color("AccentColor"),
                 background: Color("AccentColor").opacity(0.14), enabled: true) { Text(start, style: .timer).monospacedDigit() }
        } else {
            tile(.sleep, snapshot: snapshot, title: text.sleep, icon: "moon.zzz.fill", color: Color("AccentColor"),
                 background: Color("AccentColor").opacity(0.14), enabled: true) { Text(verbatim: text.startTimer) }
        }
    }

    @ViewBuilder private func since(_ date: Date?, text: WidgetText) -> some View {
        if let date { Text(date, style: .relative) } else { Text(verbatim: text.none) }
    }

    /// A viewer, or a feed with nothing to repeat, gets the same tile without the action; tapping it opens the app.
    @ViewBuilder private func tile(_ action: QuickLogAction, snapshot: QuickLogSnapshot, title: String, icon: String, color: Color,
                                   background: Color, enabled: Bool, @ViewBuilder detail: () -> some View) -> some View {
        let label = tileLabel(title: title, icon: icon, color: color, background: background, detail: detail())
        if snapshot.canWrite && enabled {
            switch action {
            case .diaper: Button(intent: LogDiaperIntent()) { label }.buttonStyle(.plain)
            case .milk: Button(intent: RepeatMilkIntent()) { label }.buttonStyle(.plain)
            case .sleep: Button(intent: ToggleSleepIntent()) { label }.buttonStyle(.plain)
            }
        } else {
            label.opacity(snapshot.canWrite ? 1 : 0.6)
        }
    }

    private func tileLabel(title: String, icon: String, color: Color, background: Color, detail: some View) -> some View {
        Group {
            if family == .systemSmall {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.footnote.weight(.semibold)).foregroundStyle(color).frame(width: 18)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        detail.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(color)
                    Spacer(minLength: 0)
                    Text(verbatim: title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    detail.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Color.primary)
        .background(background, in: .rect(cornerRadius: 12))
    }
}

/// The widget's few words, in the app's language when the app has written a snapshot, else the device's.
nonisolated struct WidgetText {
    let vietnamese: Bool
    init(language: String?) {
        vietnamese = (language ?? Locale.preferredLanguages.first ?? "en").hasPrefix("vi")
    }
    var appName: String { "Bé Khỏe" }
    var quickLog: String { vietnamese ? "Ghi nhanh" : "Quick log" }
    var widgetDescription: String { vietnamese ? "Ghi tã, cữ sữa và giấc ngủ của bé chỉ với một chạm." : "Log a diaper, a feed or a sleep with one tap." }
    var openToStart: String { vietnamese ? "Mở Bé Khỏe để bắt đầu ghi nhanh." : "Open Bé Khỏe to start logging." }
    var viewOnly: String { vietnamese ? "Chỉ xem" : "View only" }
    var diaper: String { vietnamese ? "Tã" : "Diaper" }
    var milk: String { vietnamese ? "Sữa" : "Milk" }
    var sleep: String { vietnamese ? "Ngủ" : "Sleep" }
    var wakeUp: String { vietnamese ? "Thức dậy" : "Woke up" }
    var startTimer: String { vietnamese ? "Bắt đầu" : "Start" }
    var none: String { vietnamese ? "Chưa có" : "None yet" }
    var logInApp: String { vietnamese ? "Ghi trong app" : "Log in app" }
}

extension QuickLogSnapshot {
    nonisolated static var sample: QuickLogSnapshot {
        let now = Date()
        let vietnamese = WidgetText(language: nil).vietnamese
        return QuickLogSnapshot(babyName: "Bé An", language: vietnamese ? "vi" : "en", canWrite: true,
                                lastDiaper: now.addingTimeInterval(-50 * 60), lastMilk: now.addingTimeInterval(-2 * 3600),
                                milkAmount: "120 ml", sleepStart: nil)
    }
}

#Preview(as: .systemMedium) { QuickLogWidget() } timeline: {
    QuickLogEntry(date: .now, snapshot: .sample)
    QuickLogEntry(date: .now, snapshot: nil)
}
