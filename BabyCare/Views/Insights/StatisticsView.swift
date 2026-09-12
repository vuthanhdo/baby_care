import SwiftUI
import Charts

/// Stitch S — native view backed by the existing data provider.
struct StatisticsView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var range: InsightRange = .hours48
    @State private var customInterval = InsightRange.hours48.interval()
    @State private var showRange = false
    @State private var mode: Mode = .medical
    @State private var growthMetric: GrowthMetric = .weight
    @State private var allGrowth = false
    @State private var growthList = false
    @State private var selectedGrowthDate: Date?
    @State private var foodList = false
    private enum Mode: String, CaseIterable, Identifiable {
        case medical = "Y tế", food = "Ăn & ngủ", growth = "Tăng trưởng"
        var id: Self { self }
        var color: Color { self == .medical ? CareTheme.medical : self == .food ? CareTheme.feeding : CareTheme.accent }
        var icon: String { self == .medical ? "Stitch_stethoscope" : self == .food ? "Stitch_water_bottle" : "Stitch_trending_up" }
    }
    private enum GrowthMetric: String, CaseIterable, Identifiable {
        case weight = "Cân nặng", height = "Chiều cao"
        var id: Self { self }
        var unit: String { self == .weight ? "kg" : "cm" }
        func value(_ item: BodyMeasurement) -> Double? {
            let value = self == .weight ? item.weight : item.height
            return value.flatMap { $0.isFinite ? $0 : nil }
        }
    }
    private var interval: DateInterval { range == .custom ? customInterval : range.interval() }
    private var activities: [CareActivity] { viewModel.activities.filter { interval.contains($0.date) }.sorted { $0.date > $1.date } }
    private var temperatures: [CareActivity] { activities.filter { $0.kind == .temperature } }
    private var medicines: [CareActivity] { activities.filter { $0.kind == .medicine } }
    private var growth: [BodyMeasurement] {
        viewModel.measurements.filter { (allGrowth || interval.contains($0.date)) && growthMetric.value($0) != nil }.sorted { $0.date < $1.date }
    }
    private var newestMeasurement: BodyMeasurement? {
        viewModel.measurements.filter { growthMetric.value($0) != nil }.max { $0.date < $1.date }
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker(L10n.text("Khoảng thống kê"), selection: $range) {
                    ForEach(InsightRange.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented)
                    .onChange(of: range) { _, value in if value == .custom { showRange = true } }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Mode.allCases) { item in
                            Button { mode = item } label: {
                                HStack(spacing: 6) {
                                    CareIcon(name: item.icon, color: item.color, size: 16)
                                    Text(L10n.text(item.rawValue)).font(CareFont.subheadline.weight(mode == item ? .semibold : .medium))
                                    if mode == item { Circle().fill(item.color).frame(width: 5, height: 5) }
                                }.padding(.horizontal, 14).frame(minHeight: 44)
                                    .foregroundStyle(item.color).background(item.color.opacity(0.08), in: Capsule())
                                    .overlay(Capsule().stroke(item.color.opacity(mode == item ? 0.35 : 0.15), lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityAddTraits(mode == item ? [.isSelected] : [])
                        }
                    }
                }
                if range == .custom {
                    Button { showRange = true } label: { Text(InsightData.intervalLabel(interval)).font(CareFont.caption) }
                }
                switch mode {
                case .medical: medicalContent
                case .food: foodContent
                case .growth: growthContent
                }
                NavigationLink { ShareReportView(interval: interval) } label: {
                    HStack(spacing: 8) {
                        CareIcon(name: "Stitch_ios_share", color: .white, size: 20)
                        Text(L10n.text("Chia sẻ báo cáo (PDF / QR)")).font(CareFont.callout.weight(.semibold))
                    }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                        .background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                Text(L10n.text("{0} · Dữ liệu do bố mẹ ghi nhận", "\(InsightData.intervalLabel(interval))"))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .background(CareTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showRange) {
            InsightDateRangeView(start: customInterval.start, end: customInterval.end) { customInterval = $0 }
        }
    }

    @ViewBuilder private var medicalContent: some View {
        NavigationLink { IllnessTrackingView() } label: {
            CareCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        InsightBadge(title: viewModel.isTrackingIllness ? L10n.text("Đợt theo dõi") : L10n.text("Theo dõi sức khỏe"), color: CareTheme.medical)
                        Spacer()
                        CareIcon(name: "Stitch_health_and_safety", color: CareTheme.medical, size: 24)
                    }
                    Text(viewModel.isTrackingIllness ? (viewModel.illnessTitle.isEmpty ? L10n.text("Đang theo dõi ốm") : viewModel.illnessTitle) : L10n.text("Bắt đầu theo dõi ốm"))
                        .font(CareFont.headline).foregroundStyle(CareTheme.text)
                    Text(viewModel.isTrackingIllness ? L10n.text("Bắt đầu {0} · Xem lịch thuốc và nhật ký", "\(viewModel.illnessStartDate.careFormatted(date: .abbreviated, time: .omitted))") : L10n.text("Tập trung nhiệt độ, thuốc và triệu chứng khi bé không khỏe."))
                        .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                }
            }.overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16).fill(CareTheme.medical).frame(width: 5) }
        }.buttonStyle(.plain)
        CareCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    CareIcon(name: "Stitch_device_thermostat", color: CareTheme.medical, size: 23)
                        .padding(10).background(CareTheme.medicalBackground, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("THÂN NHIỆT GẦN NHẤT")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                        Text(temperatures.first.map { "\($0.value) °C" } ?? L10n.text("Chưa ghi nhận")).font(CareFont.title.bold())
                        if let latest = temperatures.first {
                            Text(latest.date, format: .dateTime.day().month().hour().minute()).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                    }
                }
                NavigationLink { ActivityFormView(kind: .temperature) } label: {
                    Text(L10n.text("+ Ghi nhiệt độ")).font(CareFont.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        .background(CareTheme.accent.opacity(0.09), in: Capsule())
                }
                TemperatureChartView(activities: activities)
                if !medicines.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("Các lần dùng thuốc")).font(CareFont.subheadline.weight(.semibold))
                        ForEach(medicines.prefix(3)) { item in
                            NavigationLink { ActivityDetailView(activity: item) } label: { InsightActivityRow(activity: item) }
                        }
                    }.padding(12).background(CareTheme.routineBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
            }.foregroundStyle(CareTheme.text)
        }
        CareSectionTitle(title: L10n.text("Tổng quan"), subtitle: L10n.text(range.rawValue))
        nutritionMetrics
        if let latest = viewModel.measurements.max(by: { $0.date < $1.date }) {
            Button { mode = .growth } label: {
                CareCard {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_straighten", color: CareTheme.accent, size: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(measurementText(latest)).font(CareFont.headline).foregroundStyle(CareTheme.text)
                            Text(L10n.text("Đo {0}", "\(latest.date.careFormatted(date: .abbreviated, time: .omitted))")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                        Spacer()
                    }
                }
            }.buttonStyle(.plain)
        }
    }

    private var nutritionMetrics: some View {
        HStack(alignment: .top, spacing: 12) {
            InsightMetricView(title: L10n.text("Lượng sữa đã ghi"), value: InsightData.sum(activities, kind: .milk, unit: "ml").map { "\(InsightData.format($0)) ml" } ?? L10n.text("Chưa ghi nhận"), subtitle: L10n.text("Chưa gồm bú mẹ trực tiếp"), icon: "Stitch_water_bottle", color: CareTheme.feeding)
            InsightMetricView(title: L10n.text("Thời gian ngủ"), value: InsightData.sleepHours(viewModel.activities, in: interval).map { L10n.text("{0} giờ", "\(InsightData.format($0))") } ?? L10n.text("Chưa ghi nhận"), subtitle: L10n.text("Giấc ngủ đã kết thúc"), icon: "Stitch_bedtime", color: CareTheme.routine)
        }
    }

    @ViewBuilder private var foodContent: some View {
        CareSectionTitle(title: L10n.text("Ăn uống & giấc ngủ"), subtitle: InsightData.intervalLabel(interval))
        nutritionMetrics
        HStack(alignment: .top, spacing: 12) {
            InsightMetricView(title: L10n.text("Nước"), value: InsightData.sum(activities, kind: .water, unit: "ml").map { "\(InsightData.format($0)) ml" } ?? L10n.text("Chưa ghi nhận"), subtitle: L10n.text("Tổng trong khoảng"), icon: "Stitch_water_drop", color: CareTheme.feeding)
            InsightMetricView(title: L10n.text("Bữa ăn"), value: activities.filter { $0.kind == .meal }.isEmpty ? L10n.text("Chưa ghi nhận") : L10n.text("{0} bữa", "\(activities.filter { $0.kind == .meal }.count)"), subtitle: L10n.text("Theo nhật ký đã lưu"), icon: "Stitch_ramen_dining", color: CareTheme.routine)
        }
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(L10n.text("Xem dạng danh sách"), isOn: $foodList).font(CareFont.subheadline)
                if foodList {
                    ForEach(activities.filter { $0.kind.group != .medical }) { item in
                        NavigationLink { ActivityDetailView(activity: item) } label: { InsightActivityRow(activity: item) }
                    }
                    if !activities.contains(where: { $0.kind.group != .medical }) { Text(L10n.text("Chưa ghi nhận trong khoảng này")).foregroundStyle(CareTheme.secondary) }
                } else {
                    dailyChart(kind: .milk, title: L10n.text("Sữa theo ngày · ml"), color: CareTheme.feeding)
                    dailyChart(kind: .sleep, title: L10n.text("Ngủ theo ngày · giờ"), color: CareTheme.routine)
                }
            }
        }
        NavigationLink { ActivityFormView(kind: .milk) } label: { Text(L10n.text("Ghi cữ sữa")).font(CareFont.headline).frame(maxWidth: .infinity, minHeight: 48) }
    }

    private func dailyChart(kind: ActivityKind, title: String, color: Color) -> some View {
        let calendar = Calendar.current
        let days = stride(from: 0, through: min(365, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0), by: 1).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: interval.start)) }
        let values: [(date: Date, value: Double)] = days.compactMap { day in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayInterval = DateInterval(start: max(day, interval.start), end: min(dayEnd, interval.end))
            let value = kind == .sleep ? InsightData.sleepHours(viewModel.activities, in: dayInterval) : InsightData.sum(activities.filter { calendar.isDate($0.date, inSameDayAs: day) }, kind: .milk, unit: "ml")
            return value.map { (day, $0) }
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(title).font(CareFont.headline)
            if values.isEmpty {
                Text(L10n.text("Chưa ghi nhận")).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(values, id: \.date) { value in
                    BarMark(x: .value(L10n.text("Ngày"), value.date, unit: .day), y: .value(title, value.value)).foregroundStyle(color).cornerRadius(5)
                }.frame(height: 160).chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month()) } }
            }
        }
    }

    @ViewBuilder private var growthContent: some View {
        Picker(L10n.text("Chỉ số"), selection: $growthMetric) { ForEach(GrowthMetric.allCases) { Text(L10n.text($0.rawValue)).tag($0) } }.pickerStyle(.segmented)
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text("MỚI NHẤT ĐÃ GHI")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                if let latest = newestMeasurement, let value = growthMetric.value(latest) {
                    Text("\(InsightData.format(value)) \(growthMetric.unit)").font(CareFont.largeTitle.bold())
                    Text(latest.date, format: .dateTime.day().month().year()).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                } else { Text(L10n.text("Chưa ghi nhận")).font(CareFont.title2.bold()) }
                Toggle(L10n.text("Xem dạng danh sách"), isOn: $growthList).font(CareFont.subheadline)
                Text(allGrowth ? L10n.text("Toàn bộ lịch sử") : InsightData.intervalLabel(interval)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                if growth.isEmpty {
                    Text(L10n.text("Chưa có số đo trong khoảng này")).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity, minHeight: 100)
                } else if growthList {
                    ForEach(growth) { item in
                        NavigationLink { MeasurementEntryView(measurement: item) } label: {
                            HStack {
                                Text(item.date, format: .dateTime.day().month().year())
                                Spacer()
                                Text("\(InsightData.format(growthMetric.value(item) ?? 0)) \(growthMetric.unit)").fontWeight(.semibold)
                            }.font(CareFont.subheadline).padding(.vertical, 8)
                        }
                    }
                } else {
                    Chart(growth) { item in
                        if let value = growthMetric.value(item) {
                            LineMark(x: .value(L10n.text("Ngày"), item.date), y: .value(growthMetric.unit, value)).foregroundStyle(CareTheme.accent)
                            PointMark(x: .value(L10n.text("Ngày"), item.date), y: .value(growthMetric.unit, value)).foregroundStyle(CareTheme.accent)
                        }
                    }.frame(height: 195).chartYScale(domain: .automatic(includesZero: false))
                    .chartXSelection(value: $selectedGrowthDate)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.day().month()) } }
                    if let date = selectedGrowthDate, let selected = growth.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                        NavigationLink { MeasurementEntryView(measurement: selected) } label: {
                            Text(L10n.text("{0} · {1} {2} · Xem / sửa số đo", "\(selected.date.careFormatted(date: .abbreviated, time: .omitted))", "\(InsightData.format(growthMetric.value(selected) ?? 0))", "\(growthMetric.unit)"))
                                .font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.accent)
                        }
                    }
                }
                Button(allGrowth ? L10n.text("Dùng khoảng đã chọn") : L10n.text("Xem toàn bộ lịch sử")) { allGrowth.toggle() }.font(CareFont.subheadline.weight(.semibold))
                NavigationLink { MeasurementEntryView() } label: {
                    Text(L10n.text("+ Thêm số đo")).font(CareFont.headline).frame(maxWidth: .infinity, minHeight: 48)
                        .background(CareTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                }
            }.foregroundStyle(CareTheme.text)
        }
    }

    private func measurementText(_ item: BodyMeasurement) -> String {
        [item.weight.map { "\(InsightData.format($0)) kg" }, item.height.map { "\(InsightData.format($0)) cm" }].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview { NavigationStack { StatisticsView() }.environment(BabyCareViewModel.preview()) }
