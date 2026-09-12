import SwiftUI
import Charts

enum InsightRange: String, CaseIterable, Identifiable {
    case today = "Hôm nay", hours48 = "48 giờ", week = "7 ngày", custom = "Tùy chọn"
    var id: Self { self }
    func interval(now: Date = .now) -> DateInterval {
        let start: Date
        switch self {
        case .today: start = Calendar.current.startOfDay(for: now)
        case .hours48, .custom: start = now.addingTimeInterval(-48 * 3600)
        case .week: start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now)) ?? now
        }
        return DateInterval(start: start, end: now)
    }
}

enum InsightData {
    static func number(_ text: String) -> Double? {
        CareValidation.number(text)
    }
    static func format(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.locale(AppLanguage.current.locale).precision(.fractionLength(0...digits)))
    }
    static func intervalLabel(_ interval: DateInterval) -> String {
        let style = Date.FormatStyle().day().month().hour().minute().locale(AppLanguage.current.locale)
        return "\(interval.start.formatted(style)) – \(interval.end.formatted(style))"
    }
    static func sum(_ activities: [CareActivity], kind: ActivityKind, unit: String) -> Double? {
        let values = activities.filter { $0.kind == kind && $0.unit.lowercased() == unit.lowercased() }.compactMap { number($0.value) }
        let total = values.reduce(0, +)
        return values.isEmpty || !total.isFinite ? nil : total
    }
    static func sleepHours(_ activities: [CareActivity], in interval: DateInterval) -> Double? {
        let values = activities.filter { $0.kind == .sleep }.compactMap { activity -> Double? in
            guard let amount = number(activity.value), amount > 0 else { return nil }
            let seconds = amount * (["giờ", "h", "hour"].contains(activity.unit.lowercased()) ? 3600 : 60)
            guard seconds.isFinite else { return nil }
            let end = activity.date.addingTimeInterval(seconds)
            let overlap = min(end, interval.end).timeIntervalSince(max(activity.date, interval.start))
            return overlap > 0 ? overlap / 3600 : nil
        }
        let total = values.reduce(0, +)
        return values.isEmpty || !total.isFinite ? nil : total
    }
}

struct InsightBadge: View {
    let title: String
    var color = CareTheme.accent
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Text(title).font(CareFont.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.09), in: Capsule())
    }
}

struct InsightMetricView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        CareCard {
            VStack(alignment: .leading, spacing: 10) {
                CareIcon(name: icon, color: color, size: 20)
                    .padding(9).background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Text(title).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                Text(value).font(CareFont.title2.bold()).foregroundStyle(CareTheme.text)
                Text(subtitle).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InsightActivityRow: View {
    let activity: CareActivity
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        HStack(spacing: 12) {
            CareIcon(name: activity.kind.assetName, color: activity.kind.group.color, size: 20)
                .padding(9).background(activity.kind.group.background, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.kind.title).font(CareFont.subheadline.weight(.semibold))
                Text([activity.detail, [activity.value, activity.unit].filter { !$0.isEmpty }.joined(separator: " ")].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            Spacer(minLength: 4)
            Text(activity.date, format: .dateTime.hour().minute()).font(CareFont.caption.monospacedDigit()).foregroundStyle(CareTheme.secondary)
        }.foregroundStyle(CareTheme.text).padding(.vertical, 4)
    }
}

struct TemperatureChartView: View {
    let activities: [CareActivity]
    var compact = false
    @State private var selectedDate: Date?
    @State private var showList = false
    private var points: [CareActivity] {
        activities.filter { $0.kind == .temperature && InsightData.number($0.value) != nil }.sorted { $0.date < $1.date }
    }
    private var selected: CareActivity? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    private var domain: ClosedRange<Double> {
        let values = points.compactMap { InsightData.number($0.value) }
        return ((values.min() ?? 37) - 0.5)...((values.max() ?? 38) + 0.5)
    }
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("Diễn biến thân nhiệt")).font(CareFont.headline)
                    Text(L10n.text("Các điểm là lần đo đã ghi")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
                Spacer()
                Button { showList.toggle() } label: {
                    CareIcon(name: showList ? "Stitch_show_chart" : "Stitch_format_list_bulleted", color: CareTheme.accent, size: 20)
                }.frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(showList ? L10n.text("Xem biểu đồ") : L10n.text("Xem dạng danh sách"))
            }
            if points.isEmpty {
                Text(L10n.text("Chưa ghi nhận nhiệt độ trong khoảng này")).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else if showList {
                ForEach(points) { point in
                    NavigationLink { ActivityDetailView(activity: point) } label: { InsightActivityRow(activity: point) }
                }
            } else {
                Chart(points) { point in
                    if let value = InsightData.number(point.value) {
                        LineMark(x: .value(L10n.text("Thời điểm"), point.date), y: .value(L10n.text("Nhiệt độ °C"), value))
                            .foregroundStyle(CareTheme.accent).interpolationMethod(.linear)
                        PointMark(x: .value(L10n.text("Thời điểm"), point.date), y: .value(L10n.text("Nhiệt độ °C"), value))
                            .foregroundStyle(CareTheme.accent).symbolSize(selected?.id == point.id ? 90 : 35)
                    }
                }
                .chartYScale(domain: domain)
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisValueLabel() } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.day().month().hour()) } }
                .chartXSelection(value: $selectedDate)
                .frame(height: compact ? 150 : 195)
                .accessibilityLabel(L10n.text("Biểu đồ nhiệt độ, {0} lần đo. Có thể chuyển sang danh sách.", "\(points.count)"))
                if points.count == 1 {
                    Text(L10n.text("Cần thêm số đo để xem diễn biến")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
                if let selected {
                    NavigationLink { ActivityDetailView(activity: selected) } label: {
                        HStack {
                            Text("\(selected.date.careFormatted(date: .abbreviated, time: .shortened)) · \(selected.value) °C")
                            Spacer()
                            Text(L10n.text("Xem bản ghi")).fontWeight(.semibold)
                        }.font(CareFont.caption).foregroundStyle(CareTheme.accent)
                    }
                }
            }
        }.foregroundStyle(CareTheme.text)
    }
}

struct InsightDateRangeView: View {
    @Environment(\.dismiss) private var dismiss
    @State var start: Date
    @State var end: Date
    let apply: (DateInterval) -> Void
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            Form {
                DatePicker(L10n.text("Từ"), selection: $start, in: ...Date.now)
                DatePicker(L10n.text("Đến"), selection: $end, in: ...Date.now)
                if start > end { Text(L10n.text("Ngày bắt đầu phải trước ngày kết thúc")).foregroundStyle(CareTheme.medical) }
            }
            .navigationTitle(L10n.text("Khoảng thời gian")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Áp dụng")) { apply(DateInterval(start: start, end: end)); dismiss() }.disabled(start > end)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}
