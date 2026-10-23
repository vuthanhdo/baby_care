import SwiftUI

/// Stitch B — native view backed by the existing data provider.
struct QuickLogView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @AppStorage("care.habitSuggestions") private var habitSuggestions = true
    @Binding var selectedTab: CareTab
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selectedGroup: ActivityGroup?
    @State private var sleepReview: CareActivity?

    private var recent: [CareActivity] { Array(viewModel.activities.sorted { $0.date > $1.date }.prefix(3)) }
    private var lastTemperature: CareActivity? { viewModel.activities.first { $0.kind == .temperature } }
    private var lastMilk: CareActivity? { viewModel.activities.first { $0.kind == .milk } }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            // Open iPhone Duo / iPad: what is happening now on one side of the fold, logging on the other.
            CareColumns {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        Text(L10n.text("Ghi nhanh")).font(CareFont.title.bold())
                    }
                    Spacer()
                    CareBadge(title: viewModel.isDemo && !CareDemoMode.hidesDemoBadge ? L10n.text("Dữ liệu mẫu") : viewModel.state.storage == .device ? L10n.text("Trên thiết bị") : "Cloud")
                }
                if viewModel.isTrackingIllness { illnessCard }
                if let nextReminder = viewModel.medicationReminders.filter({ $0.enabled }).min(by: { $0.nextDate < $1.nextDate }) {
                    upcomingReminder(nextReminder)
                }
                if let sleepStart = viewModel.sleepStartDate { sleepCard(start: sleepStart) }
                todaySummary
                if habitSuggestions && lastMilk != nil { suggestions }
            } trailing: {
                categories
                NavigationLink { VoiceEntryView() } label: {
                    HStack(spacing: 14) {
                        CareIcon(name: "Stitch_mic", color: CareTheme.accent, size: 24)
                            .frame(width: 48, height: 48).background(CareTheme.accent.opacity(0.1), in: .circle)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.text("Nói để ghi")).font(CareFont.headline)
                            Text(L10n.text("Ví dụ: “Bé uống 120 ml sữa lúc 7 giờ sáng”"))
                                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                        Spacer(minLength: 0)
                    }.padding(16).background(CareTheme.accent.opacity(0.06), in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.accent.opacity(0.2)))
                }.buttonStyle(.plain)
                HStack {
                    Text(L10n.text("Hoạt động gần đây")).font(CareFont.headline)
                    Spacer()
                    Button(L10n.text("Xem tất cả")) { selectedTab = .diary }.font(CareFont.subheadline.weight(.semibold))
                }
                if recent.isEmpty {
                    CareCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("Chưa có ghi nhận")).font(CareFont.headline)
                            Text(L10n.text("Chọn một hoạt động phía trên để bắt đầu chăm sóc bé mỗi ngày."))
                                .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                        }
                    }
                } else {
                    CareCard {
                        VStack(spacing: 12) {
                            ForEach(recent) { activity in
                                NavigationLink { ActivityDetailView(activity: activity) } label: {
                                    CareActivityRow(activity: activity)
                                }.buttonStyle(.plain)
                                if activity.id != recent.last?.id { Divider().overlay(CareTheme.border) }
                            }
                        }
                    }
                }
                if !viewModel.isTrackingIllness {
                    NavigationLink(L10n.text("Bắt đầu theo dõi ốm")) { IllnessTrackingView() }
                        .font(CareFont.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .careScreen()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
        .sheet(item: $selectedGroup) { group in
            NavigationStack { ActivityPickerView(initialGroup: group) }.careToastBanner().presentationDetents([.large])
        }
        .sheet(item: $sleepReview) { activity in
            NavigationStack { ActivityFormView(kind: .sleep, activity: activity) }
        }
    }

    private func upcomingReminder(_ reminder: MedicationReminder) -> some View {
        CareFormCard {
            HStack(spacing: 12) {
                CareIcon(name: "Stitch_medication", color: CareTheme.medical)
                    .frame(width: 44, height: 44).background(CareTheme.medicalBackground, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(reminder.name).font(CareFont.headline)
                    Text(L10n.text("{0} {1} · Theo lịch đã lưu", "\(reminder.amount)", "\(reminder.unit)")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.text("MỐC TIẾP THEO: {0}", "\(reminder.nextDate.careFormatted(date: .omitted, time: .shortened))"), systemImage: "calendar")
                        .font(CareFont.caption)
                    if reminder.nextDate > context.date {
                        Label(L10n.text("Còn {0}", InsightData.remainingText(until: reminder.nextDate, now: context.date)), systemImage: "hourglass")
                            .font(CareFont.headline)
                    } else { Text(L10n.text("Đã đến mốc theo lịch")).font(CareFont.headline).foregroundStyle(CareTheme.medical) }
                }.foregroundStyle(CareTheme.accent).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(CareTheme.feedingBackground, in: .rect(cornerRadius: 12))
            }
            ViewThatFits(in: .horizontal) {
                HStack { reminderRecordLink(reminder); reminderScheduleLink }
                VStack { reminderRecordLink(reminder); reminderScheduleLink }
            }
        }
    }

    private func reminderRecordLink(_ reminder: MedicationReminder) -> some View {
        NavigationLink {
            ActivityFormView(kind: .medicine,
                activity: CareActivity(kind: .medicine, value: reminder.amount, unit: reminder.unit, detail: reminder.name),
                completingReminderID: reminder.id)
        } label: { Label(L10n.text("Ghi đã dùng"), systemImage: "checkmark.circle").font(CareFont.subheadline.weight(.semibold)).padding(12) }
            .buttonStyle(.plain).foregroundStyle(.white)
            .background(CareTheme.accent, in: .rect(cornerRadius: 12))
    }

    private var reminderScheduleLink: some View {
        NavigationLink { IllnessTrackingView() } label: {
            Label(L10n.text("Xem lịch thuốc"), systemImage: "calendar").font(CareFont.subheadline).padding(12)
        }.buttonStyle(.plain).foregroundStyle(CareTheme.text)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
    }

    private var illnessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("TRẠNG THÁI ĐANG DIỄN RA")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            CareCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_thermostat", color: CareTheme.medical)
                            .frame(width: 44, height: 44).background(CareTheme.medicalBackground, in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("Đang theo dõi ốm")).font(CareFont.headline).foregroundStyle(CareTheme.medical)
                            Text(viewModel.illnessTitle).font(CareFont.subheadline)
                        }
                    }
                    if let temperature = lastTemperature {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text("Nhiệt độ gần nhất")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            HStack(alignment: .firstTextBaseline) {
                                Text(temperature.formattedValue).font(CareFont.title2.bold()).foregroundStyle(CareTheme.medical)
                                Spacer()
                                Text(temperature.date, format: .dateTime.hour().minute()).font(CareFont.caption)
                            }
                        }.padding(12).background(CareTheme.medicalBackground.opacity(0.5), in: .rect(cornerRadius: 12))
                    }
                    let episode = InsightData.episodeSummary(viewModel.activities, since: viewModel.illnessStartDate)
                    if let peak = episode.peakTemperature, peak.id != lastTemperature?.id {
                        Text(L10n.text("Cao nhất trong đợt: {0} °C · {1}", "\(peak.value)", "\(peak.date.careFormatted(date: .abbreviated, time: .shortened))"))
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                    if !episode.symptomNames.isEmpty {
                        HStack(spacing: 8) {
                            Text(L10n.text("Triệu chứng gần nhất")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            SymptomChips(names: episode.symptomNames)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { temperatureLink; illnessLink }
                        VStack { temperatureLink; illnessLink }
                    }
                    symptomLink
                }
            }
        }
    }
    private var temperatureLink: some View {
        NavigationLink { ActivityFormView(kind: .temperature) } label: {
            // Narrow columns (open iPhone Duo, small phones) shrink the title a little instead of wrapping it.
            Label { Text(L10n.text("Đo nhiệt độ")).lineLimit(1).minimumScaleFactor(0.8) } icon: { CareIcon(name: "Stitch_device_thermostat", color: .white, size: 20) }
        }.buttonStyle(CareActionStyle())
    }
    private var symptomLink: some View {
        NavigationLink { ActivityFormView(kind: .symptom) } label: {
            Label(L10n.text("Ghi triệu chứng"), systemImage: "plus").font(CareFont.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
        }.foregroundStyle(CareTheme.medical)
    }
    private var illnessLink: some View {
        NavigationLink { IllnessTrackingView() } label: {
            Text(L10n.text("Xem theo dõi")).font(CareFont.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
        }.buttonStyle(.plain).accessibilityIdentifier("illness.open").padding(12).foregroundStyle(CareTheme.medical)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.medical))
    }
    private func sleepCard(start: Date) -> some View {
        CareCard {
            HStack(spacing: 14) {
                CareIcon(name: "Stitch_bedtime", color: CareTheme.routine)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("Bé đang ngủ")).font(CareFont.headline)
                    Text(start, style: .timer).monospacedDigit().foregroundStyle(CareTheme.routine)
                }
                Spacer()
                Button(L10n.text("Kết thúc")) {
                    guard let minutes = Int(exactly: (Date.now.timeIntervalSince(start) / 60).rounded(.towardZero)) else {
                        Task { await viewModel.send(.showMessage(L10n.text("Thời điểm bắt đầu giấc ngủ không hợp lệ."))) }
                        return
                    }
                    sleepReview = CareActivity(kind: .sleep, date: start,
                        value: String(max(1, minutes)), unit: "phút", detail: L10n.text("Giấc ngủ"))
                }.buttonStyle(.bordered)
            }
        }
    }
    private var todaySummary: some View {
        let summary = InsightData.daySummary(viewModel.activities)
        let showMedicine = viewModel.isTrackingIllness || summary.medicineCount > 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("HÔM NAY")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                Spacer()
                Button(L10n.text("Xem thống kê")) { selectedTab = .statistics }
                    .font(CareFont.caption.weight(.semibold)).accessibilityIdentifier("todaySummary.statistics")
            }
            CareCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 14) {
                    summaryTile(icon: "Stitch_water_bottle", color: CareTheme.feeding,
                        value: summary.feedCount > 0 ? L10n.count(summary.feedCount, one: "1 cữ", many: "{0} cữ") : nil,
                        label: [L10n.text("Sữa"), summary.bottleMilliliters.map { "\(InsightData.format($0)) ml" },
                                summary.breastfeedMinutes.map { L10n.text("{0} phút bú mẹ", InsightData.format($0)) }].compactMap { $0 }.joined(separator: " · "))
                    summaryTile(icon: "Stitch_bedtime", color: CareTheme.routine,
                        value: summary.sleepHours.map { L10n.count(InsightData.format($0), one: "1 giờ", many: "{0} giờ") },
                        label: summary.sleepCount == 0 ? L10n.text("Ngủ") : L10n.count(summary.sleepCount, one: "Ngủ · 1 giấc", many: "Ngủ · {0} giấc"))
                    summaryTile(icon: "Stitch_baby_changing_station", color: CareTheme.routine,
                        value: summary.diaperCount > 0 ? L10n.count(summary.diaperCount, one: "1 lần", many: "{0} lần") : nil,
                        label: summary.lastDiaper.map { L10n.text("Tã · Gần nhất {0}", $0.careFormatted(date: .omitted, time: .shortened)) } ?? L10n.text("Tã"))
                    if showMedicine {
                        summaryTile(icon: "Stitch_medication", color: CareTheme.medical,
                            value: summary.medicineCount > 0 ? L10n.count(summary.medicineCount, one: "1 lần", many: "{0} lần") : nil, label: L10n.text("Thuốc"))
                    } else {
                        summaryTile(icon: "Stitch_ramen_dining", color: CareTheme.feeding,
                            value: summary.mealCount > 0 ? L10n.count(summary.mealCount, one: "1 bữa", many: "{0} bữa") : nil,
                            label: summary.waterMilliliters.map { L10n.text("Bữa ăn · {0} ml nước", InsightData.format($0)) } ?? L10n.text("Bữa ăn"))
                    }
                }
            }
        }
    }
    /// `value` nil shows a dash and reads as "not recorded" to VoiceOver.
    private func summaryTile(icon: String, color: Color, value: String?, label: String) -> some View {
        HStack(spacing: 10) {
            CareIcon(name: icon, color: color, size: 20)
                .frame(width: 36, height: 36).background(color.opacity(0.1), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(value ?? "—").font(CareFont.headline).foregroundStyle(CareTheme.text).monospacedDigit()
                    .accessibilityLabel(value ?? L10n.text("Chưa ghi nhận"))
                Text(label).font(CareFont.caption).foregroundStyle(CareTheme.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .combine)
    }
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("GỢI Ý LÚC NÀY")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            CareCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_water_bottle", color: CareTheme.feeding)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("Ghi cữ sữa")).font(CareFont.headline)
                            if let lastMilk { Text(L10n.text("Lần trước: {0}. Kiểm tra lượng mới trước khi lưu.", "\(lastMilk.formattedValue)")).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                        }
                    }
                    NavigationLink { ActivityFormView(kind: .milk) } label: {
                        Label { Text(L10n.text("Ghi cữ sữa")) } icon: { CareIcon(name: "Stitch_add_circle", color: .white, size: 20) }
                    }.buttonStyle(CareActionStyle(color: CareTheme.feeding))
                }
            }
            if viewModel.sleepStartDate == nil {
                CareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            CareIcon(name: "Stitch_bedtime", color: CareTheme.routine)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.text("Giấc ngủ của bé")).font(CareFont.headline)
                                Text(L10n.text("Bấm khi bé bắt đầu ngủ để tính thời gian.")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            }
                        }
                        CarePrimaryButton(title: L10n.text("Bắt đầu ngủ"), color: CareTheme.routine, icon: "Stitch_play_arrow") {
                            Task { await viewModel.send(.commit(.startSleep(babyID: viewModel.baby.id, date: Date()))) }
                        }.tint(CareTheme.routine)
                    }
                }
            }
        }
    }
    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("DANH MỤC GHI CHÉP")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            ForEach(ActivityGroup.allCases) { group in
                Button { selectedGroup = group } label: {
                    CareCard {
                        HStack(spacing: 14) {
                            CareIcon(name: group.assetName, color: group.color, size: 24)
                                .frame(width: 48, height: 48).background(group.background, in: .rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group == .medical ? L10n.text("Y tế & Triệu chứng") : group == .feeding ? L10n.text("Ăn uống & Dinh dưỡng") : L10n.text("Ngủ & Sinh hoạt")).font(CareFont.headline)
                                Text(group == .medical ? L10n.text("Uống thuốc, nhiệt độ, triệu chứng, khám bệnh") : group == .feeding ? L10n.text("Sữa, bữa ăn, uống nước") : L10n.text("Giấc ngủ, tắm, thay tã / vệ sinh"))
                                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(group.color).frame(width: 32, height: 32).background(CareTheme.background, in: .circle)
                        }.foregroundStyle(CareTheme.text)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier(group == .medical ? "medicalGroupButton" : "\(group.rawValue)GroupButton")
            }
        }
    }
}

#Preview { NavigationStack { QuickLogView(selectedTab: .constant(.quick)) }.environment(BabyCareViewModel.preview()) }
