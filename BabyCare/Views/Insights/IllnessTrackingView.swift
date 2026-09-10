import SwiftUI

/// Stitch I — native view backed by the existing data provider.
struct IllnessTrackingView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var draftTitle = ""
    @State private var draftStart = Date()
    @State private var reminder: MedicationReminder?
    @State private var showEnd = false
    @State private var deleteReminder: MedicationReminder?
    private var latestTemperature: CareActivity? { viewModel.activities.filter { $0.kind == .temperature }.max { $0.date < $1.date } }
    private var recent: [CareActivity] {
        viewModel.activities.filter { $0.kind.group == .medical && (!viewModel.isTrackingIllness || $0.date >= viewModel.illnessStartDate) }.sorted { $0.date > $1.date }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                episodeCard
                HStack {
                    CareSectionTitle(title: "Lịch nhắc thuốc của bé")
                    Spacer()
                    Button { reminder = MedicationReminder(episodeOnly: viewModel.isTrackingIllness) } label: {
                        HStack(spacing: 5) { CareIcon(name: "InsightsAdd", color: CareTheme.accent, size: 18); Text("Thêm nhắc").font(CareFont.subheadline) }
                    }.frame(minHeight: 44)
                }
                if viewModel.medicationReminders.isEmpty {
                    CareCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Chưa đặt nhắc thuốc").font(CareFont.headline)
                            Text("Đặt mốc theo hướng dẫn bạn đã có. Lịch nhắc không phải bản ghi đã uống.").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            Button("Thêm nhắc thuốc") { reminder = MedicationReminder(episodeOnly: viewModel.isTrackingIllness) }.font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }
                    }
                } else {
                    ForEach(viewModel.medicationReminders) { item in reminderCard(item) }
                }
                HStack(alignment: .top, spacing: 12) {
                    CareIcon(name: "InsightsShield", color: CareTheme.accent, size: 24)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Lưu ý khi ghi thuốc").font(CareFont.subheadline.weight(.semibold))
                        Text("Kiểm tra tên thuốc, lượng thực tế và thời điểm theo hướng dẫn đang có trước khi lưu.").font(CareFont.subheadline)
                    }
                }.foregroundStyle(CareTheme.accent).padding(16).background(CareTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                CareSectionTitle(title: "Nhật ký đợt ốm gần đây", subtitle: "3 sự kiện mới nhất")
                CareCard {
                    VStack(spacing: 10) {
                        if recent.isEmpty { Text("Chưa có hoạt động y tế trong đợt này").foregroundStyle(CareTheme.secondary) }
                        ForEach(recent.prefix(3)) { activity in
                            NavigationLink { ActivityDetailView(activity: activity) } label: { InsightActivityRow(activity: activity) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                NavigationLink { ShareReportView() } label: {
                    HStack(spacing: 8) {
                        CareIcon(name: "InsightsShare", color: .white, size: 20)
                        Text("Xuất báo cáo 48 giờ (PDF / QR)").font(CareFont.callout.weight(.semibold))
                    }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                        .background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding(20)
        }
        .background(CareTheme.background).foregroundStyle(CareTheme.text)
        .navigationTitle("Theo dõi ốm & Lịch thuốc").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $reminder) { item in MedicationReminderView(reminder: item) }
        .alert("Kết thúc đợt theo dõi?", isPresented: $showEnd) {
            Button("Hủy", role: .cancel) { }
            Button("Kết thúc theo dõi", role: .destructive) { endEpisode() }
        } message: { Text("Dừng các nhắc chỉ thuộc đợt này. Nhật ký và các lịch riêng vẫn được giữ.") }
        .alert("Xóa lịch nhắc?", isPresented: Binding(get: { deleteReminder != nil }, set: { if !$0 { deleteReminder = nil } })) {
            Button("Hủy", role: .cancel) { deleteReminder = nil }
            Button("Xóa lịch", role: .destructive) {
                guard let item = deleteReminder else { return }
                Task {
                    if await viewModel.send(.commit(.deleteReminder(babyID: viewModel.baby.id, reminderID: item.id), message: "Đã xóa lịch nhắc")) { deleteReminder = nil }
                }
            }
        } message: { Text("Các lần uống thuốc đã ghi vẫn được giữ trong nhật ký.") }
    }

    private var episodeCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    InsightBadge(title: viewModel.isTrackingIllness ? "ĐANG THEO DÕI · NGÀY \(max(1, (Calendar.current.dateComponents([.day], from: viewModel.illnessStartDate, to: Date()).day ?? 0) + 1))" : "THEO DÕI SỨC KHỎE", color: CareTheme.medical)
                    Spacer(minLength: 4)
                    if viewModel.isTrackingIllness { Button("Kết thúc") { showEnd = true }.font(CareFont.caption.weight(.semibold)).tint(CareTheme.routine).frame(minHeight: 44) }
                }
                if viewModel.isTrackingIllness {
                    Text(viewModel.illnessTitle.isEmpty ? "Đang theo dõi ốm" : viewModel.illnessTitle).font(CareFont.title3.bold())
                    Text("Khởi phát: \(viewModel.illnessStartDate.careFormatted(date: .abbreviated, time: .omitted))").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    HStack(spacing: 12) {
                        CareIcon(name: "InsightsTemperature", color: CareTheme.medical, size: 26)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nhiệt độ gần nhất").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            Text(latestTemperature.map { "\($0.value) °C" } ?? "Chưa ghi nhận").font(CareFont.title2.bold()).foregroundStyle(CareTheme.medical)
                        }
                        Spacer()
                        if let latestTemperature { Text(latestTemperature.date, format: .dateTime.hour().minute()).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                    }.padding(14).background(CareTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 10) {
                        NavigationLink { ActivityFormView(kind: .temperature) } label: {
                            Text("Đo nhiệt độ").frame(maxWidth: .infinity, minHeight: 48).background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                        }
                        NavigationLink { ActivityFormView(kind: .medicine) } label: {
                            Text("Ghi uống thuốc").frame(maxWidth: .infinity, minHeight: 48).background(CareTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.font(CareFont.subheadline.weight(.semibold))
                } else {
                    Text("Tập trung nhiệt độ, thuốc và triệu chứng khi bé không khỏe").font(CareFont.headline)
                    TextField("Tên đợt (tùy chọn)", text: $draftTitle).textFieldStyle(.roundedBorder)
                    DatePicker("Ngày bắt đầu", selection: $draftStart, in: min(viewModel.baby.birthDate, Date.now)...Date.now, displayedComponents: .date).font(CareFont.subheadline)
                    CarePrimaryButton(title: "Bắt đầu theo dõi") {
                        Task { await viewModel.send(.commit(.startIllness(babyID: viewModel.baby.id, title: draftTitle, date: draftStart), message: "Đã bắt đầu theo dõi")) }
                    }
                }
            }
        }.background(CareTheme.medicalBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func reminderCard(_ item: MedicationReminder) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    CareIcon(name: "InsightsMedicine", color: CareTheme.medical, size: 25)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name).font(CareFont.headline)
                        Text("Lượng đã nhập: \(item.amount) \(item.unit)").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }
                    Spacer(minLength: 4)
                    Menu {
                        Button("Sửa lịch") { reminder = item }
                        Button("Xóa lịch", role: .destructive) { deleteReminder = item }
                    } label: { CareIcon(name: "InsightsEdit", color: CareTheme.secondary, size: 20) }.frame(minWidth: 44, minHeight: 44)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            CareIcon(name: "InsightsClock", color: CareTheme.accent, size: 17)
                            Text(item.enabled ? "MỐC ĐÃ ĐẶT: \(item.nextDate.careFormatted(date: .omitted, time: .shortened))" : "ĐÃ TẠM DỪNG").font(CareFont.caption.weight(.bold))
                        }
                        if item.enabled {
                            if item.nextDate > context.date {
                                HStack { Text("Còn"); Text(timerInterval: context.date...item.nextDate, countsDown: true).monospacedDigit() }.font(CareFont.subheadline.weight(.semibold))
                            } else { Text("Đã đến mốc theo lịch").font(CareFont.subheadline.weight(.semibold)) }
                        }
                        if !item.note.isEmpty { Text(item.note).font(CareFont.caption) }
                    }.foregroundStyle(CareTheme.accent).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(CareTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    Text(item.nextDate, format: .dateTime.day().month().year()).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    Spacer()
                    NavigationLink {
                        ActivityFormView(kind: .medicine,
                            activity: CareActivity(kind: .medicine, value: item.amount, unit: item.unit, detail: item.name),
                            completingReminderID: item.id)
                    } label: { Text("Ghi đã dùng").font(CareFont.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44).background(CareTheme.accent, in: Capsule()).foregroundStyle(.white) }
                }
            }
        }
    }

    private func endEpisode() {
        Task { await viewModel.send(.commit(.endIllness(babyID: viewModel.baby.id), message: "Đã kết thúc theo dõi")) }
    }

}

struct MedicationReminderView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State var reminder: MedicationReminder
    @State private var isSaving = false
    @State private var error: String?
    private var valid: Bool { !reminder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (InsightData.number(reminder.amount) ?? 0) > 0 && !reminder.unit.isEmpty && (!reminder.enabled || reminder.nextDate > Date()) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Thuốc theo hướng dẫn đã có") {
                    TextField("Tên thuốc · Bắt buộc", text: $reminder.name)
                    TextField("Lượng thực tế · Bắt buộc", text: $reminder.amount).keyboardType(.decimalPad)
                    Picker("Đơn vị", selection: $reminder.unit) { ForEach(["ml", "mg", "viên", "gói", "giọt"], id: \.self) { Text($0) } }
                }
                Section {
                    DatePicker("Mốc nhắc tiếp theo", selection: $reminder.nextDate, in: Date.now...)
                    Toggle("Bật nhắc", isOn: $reminder.enabled)
                    if viewModel.isTrackingIllness { Toggle("Chỉ trong đợt theo dõi này", isOn: $reminder.episodeOnly) }
                } header: { Text("Mốc do bạn đặt") } footer: { Text("Lịch này nhắc một lần tại mốc đã chọn. Sau khi ghi đã dùng, đặt mốc tiếp theo theo hướng dẫn của bạn.") }
                Section("Ghi chú") { TextField("Lời dặn hoặc ghi chú", text: $reminder.note, axis: .vertical).lineLimit(3...6) }
                if let error { Text(error).foregroundStyle(CareTheme.medical) }
                if !valid { Text("Nhập tên, lượng dương và mốc trong tương lai để lưu nhắc.").foregroundStyle(CareTheme.secondary) }
            }
            .navigationTitle("Nhắc thuốc").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) { Button(isSaving ? "Đang lưu…" : "Lưu") { Task { await save() } }.disabled(!valid || isSaving) }
            }
        }
    }
    @MainActor private func save() async {
        isSaving = true
        defer { isSaving = false }
        guard await viewModel.send(.commit(.saveReminder(babyID: viewModel.baby.id, reminder: reminder), message: "Đã lưu lịch nhắc")) else {
            error = viewModel.state.error ?? "Chưa lưu được. Hãy thử lại."
            return
        }
        dismiss()
    }
}

#Preview { NavigationStack { IllnessTrackingView() }.environment(BabyCareViewModel.preview()) }
