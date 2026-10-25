import SwiftUI
import Charts

/// Weight or height against age in months, with the chosen standard's percentile lines for the baby's sex.
/// Pinch or use the buttons to zoom; drag sideways to move through the months.
struct GrowthChartView<Accessory: View>: View {
    let measurements: [BodyMeasurement]
    let metric: GrowthMetric
    let profile: BabyProfile
    var height: CGFloat = 240
    @ViewBuilder var accessory: (BodyMeasurement) -> Accessory

    @AppStorage(GrowthStandard.preferenceKey) private var standardRaw = GrowthStandard.cdc.rawValue
    @State private var visibleMonths: Double?
    @State private var zoomStart: Double?
    @State private var scrollX: Double?
    @State private var selectedAge: Double?
    @Environment(\.locale) private var appLocale

    private struct Point: Identifiable {
        let item: BodyMeasurement
        let age: Double
        let value: Double
        var id: UUID { item.id }
    }
    private var standard: GrowthStandard { GrowthStandard(rawValue: standardRaw) ?? .cdc }
    private var points: [Point] {
        measurements.compactMap { item in
            metric.value(item).map { Point(item: item, age: GrowthReference.ageInMonths(from: profile.birthDate, to: item.date), value: $0) }
        }.sorted { $0.age < $1.age }
    }
    private var curves: [GrowthReference.CurvePoint] {
        GrowthReference.curves(standard: standard, metric: metric, gender: profile.gender, through: span.upperBound)
    }
    /// From birth to a little past the latest of today and the last measurement.
    private var span: ClosedRange<Double> {
        let today = GrowthReference.ageInMonths(from: profile.birthDate, to: Date())
        let last = max(today, points.last?.age ?? 0)
        return 0...max(3, (last + max(1, last * 0.08)).rounded(.up))
    }
    private var visible: Double { min(span.upperBound, max(GrowthChartZoom.minimumMonths, visibleMonths ?? span.upperBound)) }
    private var windowStart: Double { min(max(0, scrollX ?? span.upperBound - visible), span.upperBound - visible) }
    /// The y range follows what is on screen, so zooming into the first months is not flattened by later values.
    private var yDomain: ClosedRange<Double> {
        let window = windowStart...(windowStart + visible)
        let values = points.filter { window.contains($0.age) }.map(\.value)
            + curves.filter { window.contains($0.age) }.flatMap { [$0.p3, $0.p97] }
        guard let low = values.min(), let high = values.max() else { return metric == .weight ? 2...12 : 45...80 }
        let pad = max((high - low) * 0.08, metric == .weight ? 0.3 : 1)
        return max(0, low - pad)...(high + pad)
    }
    private var selected: Point? {
        guard let selectedAge else { return nil }
        return points.min { abs($0.age - selectedAge) < abs($1.age - selectedAge) }
    }

    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                let badge = Label(standard.shortTitle, systemImage: "chart.line.uptrend.xyaxis").font(CareFont.caption.weight(.semibold))
                    .padding(.horizontal, 10).frame(minHeight: 32).background(CareTheme.accent.opacity(0.08), in: .capsule)
                if GrowthStandard.allCases.count > 1 {
                    Menu {
                        Picker(L10n.text("Chuẩn tăng trưởng"), selection: $standardRaw) {
                            ForEach(GrowthStandard.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                    } label: { badge }.accessibilityIdentifier("growth.standard")
                } else {
                    badge.foregroundStyle(CareTheme.accent).accessibilityLabel(standard.title).accessibilityIdentifier("growth.standard")
                }
                Spacer(minLength: 0)
                zoomButton("minus.magnifyingglass", label: L10n.text("Thu nhỏ biểu đồ"), factor: 1.6).disabled(visible >= span.upperBound)
                zoomButton("plus.magnifyingglass", label: L10n.text("Phóng to biểu đồ"), factor: 1 / 1.6).disabled(visible <= GrowthChartZoom.minimumMonths)
                    .accessibilityIdentifier("growth.zoomIn")
            }
            chart
            // Outside the chart: an axis label inside a scrolling chart moves with the plot.
            Text(L10n.text("Tháng tuổi")).font(CareFont.caption2).foregroundStyle(CareTheme.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            legend
            if profile.gender == .unspecified {
                Text(L10n.text("Chọn giới tính trong hồ sơ bé để hiện đường chuẩn."))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            } else if curves.isEmpty {
                Text(L10n.text("Chuẩn này không có số liệu cho độ tuổi đang xem."))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            if let selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selected.item.date.careFormatted(date: .abbreviated, time: .omitted)) · \(InsightData.format(selected.value)) \(metric.unit)")
                        .font(CareFont.caption.weight(.semibold))
                    if let percentile = GrowthReference.percentile(of: selected.value, ageInMonths: selected.age, standard: standard, metric: metric, gender: profile.gender) {
                        Text(L10n.text("Khoảng bách phân vị {0} theo {1}", "\(percentile)", standard.shortTitle))
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                    accessory(selected.item)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(curves) { point in
                AreaMark(x: .value(L10n.text("Tháng tuổi"), point.age), yStart: .value(metric.unit, point.p3), yEnd: .value(metric.unit, point.p97))
                    .foregroundStyle(CareTheme.accent.opacity(0.07)).interpolationMethod(.catmullRom)
            }
            ForEach(GrowthReference.Line.allCases) { line in
                ForEach(curves) { point in
                    LineMark(x: .value(L10n.text("Tháng tuổi"), point.age), y: .value(metric.unit, point.value(line)), series: .value("Line", line.rawValue))
                        .foregroundStyle(CareTheme.secondary.opacity(line == .p50 ? 0.7 : 0.35))
                        .lineStyle(StrokeStyle(lineWidth: line == .p50 ? 1.5 : 1, dash: line == .p50 ? [] : [4, 3]))
                        .interpolationMethod(.catmullRom)
                }
            }
            ForEach(points) { point in
                LineMark(x: .value(L10n.text("Tháng tuổi"), point.age), y: .value(metric.unit, point.value), series: .value("Line", "baby"))
                    .foregroundStyle(CareTheme.accent).lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value(L10n.text("Tháng tuổi"), point.age), y: .value(metric.unit, point.value))
                    .foregroundStyle(CareTheme.accent).symbolSize(selected?.id == point.id ? 110 : 40)
            }
        }
        .frame(height: height)
        .chartXScale(domain: span)
        .chartYScale(domain: yDomain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visible)
        .chartScrollPosition(x: Binding(get: { windowStart }, set: { scrollX = $0 }))
        .chartXSelection(value: $selectedAge)
        .chartXAxis {
            AxisMarks(values: .stride(by: GrowthChartZoom.tickStride(for: visible))) { value in
                AxisGridLine()
                AxisValueLabel { if let months = value.as(Double.self) { Text("\(Int(months.rounded()))") } }
            }
        }
        .simultaneousGesture(MagnifyGesture()
            .onChanged { gesture in
                let start = zoomStart ?? visible
                zoomStart = start
                setVisible(start / gesture.magnification)
            }
            .onEnded { _ in zoomStart = nil })
        .accessibilityLabel(L10n.text("Biểu đồ {0} theo tháng tuổi", L10n.text(metric.rawValue).lowercased()))
        .accessibilityIdentifier("growth.chart")
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(L10n.text("Bé"), color: CareTheme.accent, dashed: false, width: 2.5)
            if !curves.isEmpty {
                legendItem("P50", color: CareTheme.secondary.opacity(0.7), dashed: false, width: 1.5)
                legendItem("P15 · P85", color: CareTheme.secondary.opacity(0.5), dashed: true, width: 1)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(CareTheme.accent.opacity(0.12)).frame(width: 14, height: 10)
                    Text("P3–P97")
                }
            }
        }.font(CareFont.caption2).foregroundStyle(CareTheme.secondary).accessibilityElement(children: .combine)
    }

    private func legendItem(_ title: String, color: Color, dashed: Bool, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Path { path in path.move(to: CGPoint(x: 0, y: 5)); path.addLine(to: CGPoint(x: 16, y: 5)) }
                .stroke(color, style: StrokeStyle(lineWidth: width, dash: dashed ? [4, 3] : [])).frame(width: 16, height: 10)
            Text(title)
        }
    }

    private func zoomButton(_ icon: String, label: String, factor: Double) -> some View {
        Button { withAnimation(.snappy) { setVisible(visible * factor) } } label: {
            Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }.accessibilityLabel(label)
    }

    private func setVisible(_ months: Double) {
        let end = windowStart + visible
        let clamped = min(span.upperBound, max(GrowthChartZoom.minimumMonths, months))
        visibleMonths = clamped
        // Keep the right edge (usually the newest measurement) in place while zooming.
        scrollX = max(0, min(span.upperBound - clamped, end - clamped))
    }
}

nonisolated enum GrowthChartZoom {
    static let minimumMonths = 3.0
    static func tickStride(for visibleMonths: Double) -> Double {
        switch visibleMonths {
        case ..<7: 1
        case ..<15: 2
        case ..<30: 3
        case ..<61: 6
        default: 12
        }
    }
}
