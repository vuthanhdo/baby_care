import SwiftUI

/// Stitch B — native view backed by the existing data provider.
struct QuickLogView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @AppStorage("care.habitSuggestions") private var habitSuggestions = true
    @Binding var selectedTab: CareTab
    @State private var selectedGroup: ActivityGroup?
    @State private var sleepReview: CareActivity?

    private var recent: [CareActivity] { Array(viewModel.activities.sorted { $0.date > $1.date }.prefix(3)) }
    private var lastTemperature: CareActivity? { viewModel.activities.first { $0.kind == .temperature } }
    private var lastMilk: CareActivity? { viewModel.activities.first { $0.kind == .milk } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        Text("Ghi nhanh").font(CareFont.title.bold())
                    }
                    Spacer()
                    CareBadge(title: viewModel.isDemo ? "Dữ liệu mẫu" : viewModel.state.storage == .device ? "Trên thiết bị" : "Cloud")
                }
                if viewModel.isTrackingIllness { illnessCard }
                if let nextReminder = viewModel.medicationReminders.filter({ $0.enabled }).min(by: { $0.nextDate < $1.nextDate }) {
                    upcomingReminder(nextReminder)
                }
                if let sleepStart = viewModel.sleepStartDate { sleepCard(start: sleepStart) }
                if habitSuggestions && lastMilk != nil { suggestions }
                categories
                NavigationLink { VoiceEntryView() } label: {
                    HStack(spacing: 14) {
                        CareIcon(name: "Stitch_mic", color: CareTheme.accent, size: 24)
                            .frame(width: 48, height: 48).background(CareTheme.accent.opacity(0.1), in: .circle)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Nói để ghi").font(CareFont.headline)
                            Text("Ví dụ: “Bé uống 120 ml sữa lúc 7 giờ sáng”")
                                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                        Spacer(minLength: 0)
                    }.padding(16).background(CareTheme.accent.opacity(0.06), in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.accent.opacity(0.2)))
                }.buttonStyle(.plain)
                HStack {
                    Text("Hoạt động gần đây").font(CareFont.headline)
                    Spacer()
                    Button("Xem tất cả") { selectedTab = .diary }.font(CareFont.subheadline.weight(.semibold))
                }
                if recent.isEmpty {
                    CareCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chưa có ghi nhận").font(CareFont.headline)
                            Text("Chọn một hoạt động phía trên để bắt đầu chăm sóc bé mỗi ngày.")
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
                    NavigationLink("Bắt đầu theo dõi ốm") { IllnessTrackingView() }
                        .font(CareFont.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
        .sheet(item: $selectedGroup) { group in
            NavigationStack { ActivityPickerView(initialGroup: group) }.presentationDetents([.large])
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
                    Text("\(reminder.amount) \(reminder.unit) · Theo lịch đã lưu").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Label("MỐC TIẾP THEO: \(reminder.nextDate.careFormatted(date: .omitted, time: .shortened))", systemImage: "calendar")
                        .font(CareFont.caption)
                    if reminder.nextDate > context.date {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("Còn")
                            Text(timerInterval: context.date...reminder.nextDate, countsDown: true).monospacedDigit()
                        }.font(CareFont.headline)
                    } else { Text("Đã đến mốc theo lịch").font(CareFont.headline) }
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
        } label: { Label("Ghi đã dùng", systemImage: "checkmark.circle").font(CareFont.subheadline.weight(.semibold)).padding(12) }
            .buttonStyle(.plain).foregroundStyle(.white)
            .background(CareTheme.accent, in: .rect(cornerRadius: 12))
    }

    private var reminderScheduleLink: some View {
        NavigationLink { IllnessTrackingView() } label: {
            Label("Xem lịch thuốc", systemImage: "calendar").font(CareFont.subheadline).padding(12)
        }.buttonStyle(.plain).foregroundStyle(CareTheme.text)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
    }

    private var illnessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRẠNG THÁI ĐANG DIỄN RA").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            CareCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_thermostat", color: CareTheme.medical)
                            .frame(width: 44, height: 44).background(CareTheme.medicalBackground, in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Đang theo dõi ốm").font(CareFont.headline).foregroundStyle(CareTheme.medical)
                            Text(viewModel.illnessTitle).font(CareFont.subheadline)
                        }
                    }
                    if let temperature = lastTemperature {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nhiệt độ gần nhất").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            HStack(alignment: .firstTextBaseline) {
                                Text(temperature.formattedValue).font(CareFont.title2.bold()).foregroundStyle(CareTheme.medical)
                                Spacer()
                                Text(temperature.date, format: .dateTime.hour().minute()).font(CareFont.caption)
                            }
                        }.padding(12).background(CareTheme.medicalBackground.opacity(0.5), in: .rect(cornerRadius: 12))
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { temperatureLink; illnessLink }
                        VStack { temperatureLink; illnessLink }
                    }
                }
            }
        }
    }
    private var temperatureLink: some View {
        NavigationLink { ActivityFormView(kind: .temperature) } label: {
            Label { Text("Đo nhiệt độ") } icon: { CareIcon(name: "Stitch_device_thermostat", color: .white, size: 20) }
        }.buttonStyle(CareActionStyle())
    }
    private var illnessLink: some View {
        NavigationLink { IllnessTrackingView() } label: {
            Text("Xem theo dõi").font(CareFont.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
        }.buttonStyle(.plain).padding(12).foregroundStyle(CareTheme.medical)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.medical))
    }
    private func sleepCard(start: Date) -> some View {
        CareCard {
            HStack(spacing: 14) {
                CareIcon(name: "Stitch_bedtime", color: CareTheme.routine)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bé đang ngủ").font(CareFont.headline)
                    Text(start, style: .timer).monospacedDigit().foregroundStyle(CareTheme.routine)
                }
                Spacer()
                Button("Kết thúc") {
                    guard let minutes = Int(exactly: (Date.now.timeIntervalSince(start) / 60).rounded(.towardZero)) else {
                        Task { await viewModel.send(.showMessage("Thời điểm bắt đầu giấc ngủ không hợp lệ.")) }
                        return
                    }
                    sleepReview = CareActivity(kind: .sleep, date: start,
                        value: String(max(1, minutes)), unit: "phút", detail: "Giấc ngủ")
                }.buttonStyle(.bordered)
            }
        }
    }
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GỢI Ý LÚC NÀY").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            CareCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_water_bottle", color: CareTheme.feeding)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ghi cữ sữa").font(CareFont.headline)
                            if let lastMilk { Text("Lần trước: \(lastMilk.formattedValue). Kiểm tra lượng mới trước khi lưu.").font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                        }
                    }
                    NavigationLink { ActivityFormView(kind: .milk) } label: {
                        Label { Text("Ghi cữ sữa") } icon: { CareIcon(name: "Stitch_add_circle", color: .white, size: 20) }
                    }.buttonStyle(CareActionStyle(color: CareTheme.feeding))
                }
            }
            if viewModel.sleepStartDate == nil {
                CareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            CareIcon(name: "Stitch_bedtime", color: CareTheme.routine)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Giấc ngủ của bé").font(CareFont.headline)
                                Text("Bấm khi bé bắt đầu ngủ để tính thời gian.").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            }
                        }
                        CarePrimaryButton(title: "Bắt đầu ngủ", color: CareTheme.routine, icon: "Stitch_play_arrow") {
                            Task { await viewModel.send(.commit(.startSleep(babyID: viewModel.baby.id, date: Date()))) }
                        }.tint(CareTheme.routine)
                    }
                }
            }
        }
    }
    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANH MỤC GHI CHÉP").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
            ForEach(ActivityGroup.allCases) { group in
                Button { selectedGroup = group } label: {
                    CareCard {
                        HStack(spacing: 14) {
                            CareIcon(name: group.assetName, color: group.color, size: 24)
                                .frame(width: 48, height: 48).background(group.background, in: .rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group == .medical ? "Y tế & Triệu chứng" : group == .feeding ? "Ăn uống & Dinh dưỡng" : "Ngủ & Sinh hoạt").font(CareFont.headline)
                                Text(group == .medical ? "Uống thuốc, nhiệt độ, triệu chứng, khám bệnh" : group == .feeding ? "Sữa, bữa ăn, uống nước" : "Giấc ngủ, tắm, thay tã / vệ sinh")
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
