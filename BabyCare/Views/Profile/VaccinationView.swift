import SwiftUI

struct VaccinationHistoryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    let babyID: UUID
    @State private var draft: VaccinationRecord?
    @State private var completingID: UUID?
    @State private var deleting: VaccinationRecord?
    private var baby: BabyData? { viewModel.state.database.babies.first { $0.profile.id == babyID } }
    private var history: [VaccinationRecord] { (baby?.vaccinations ?? []).sorted { $0.date > $1.date } }

    var body: some View {
        List {
            if !viewModel.state.vaccinationsAvailable { Text(L10n.text("Tính năng tiêm chủng chưa sẵn sàng trên cloud. Dữ liệu khác vẫn sử dụng được.")) }
            if history.isEmpty {
                ContentUnavailableView(L10n.text("Chưa có lịch sử tiêm chủng"), systemImage: "syringe", description: Text(L10n.text("Ghi lại các mũi đã tiêm và lịch hẹn tiếp theo.")))
            }
            ForEach(history) { record in
                VStack(alignment: .leading, spacing: 10) {
                    Button { completingID = nil; draft = record } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.vaccineName).font(CareFont.headline)
                            Text(L10n.text("Mũi {0}", String(record.doseNumber)))
                            Text(record.date.careFormatted(date: .abbreviated, time: .shortened))
                            if !record.clinic.isEmpty { Text(record.clinic) }
                            if !record.notes.isEmpty { Text(record.notes).font(CareFont.footnote) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain).disabled(!viewModel.state.vaccinationsAvailable)
                    if let next = record.nextDoseDate {
                        Text(L10n.text("Mũi tiếp theo: {0}", next.careFormatted(date: .abbreviated, time: .shortened)))
                            .foregroundStyle(next < Date() ? CareTheme.medical : CareTheme.accent)
                        if next < Date() { Text(L10n.text("Đã qua ngày hẹn")).font(CareFont.footnote) }
                        if record.reminderEnabled, let reminder = record.reminderDate {
                            Text(L10n.text("Nhắc trước: {0}", reminder.careFormatted(date: .abbreviated, time: .shortened))).font(CareFont.footnote)
                        }
                        Button(L10n.text("Ghi mũi tiếp theo")) {
                            completingID = record.id
                            draft = VaccinationRecord(vaccineName: record.vaccineName, doseNumber: record.doseNumber + 1, clinic: record.clinic)
                        }.disabled(record.doseNumber >= 1000 || !viewModel.state.vaccinationsAvailable)
                    }
                }.padding(.vertical, 6)
                .swipeActions {
                    Button(L10n.text("Xóa"), role: .destructive) { deleting = record }.disabled(!viewModel.state.vaccinationsAvailable)
                }
            }
            if let error = viewModel.state.error { Text(error).foregroundStyle(CareTheme.medical) }
        }
        .navigationTitle(L10n.text("Lịch sử tiêm chủng"))
        .navigationSubtitle(baby?.profile.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.text("Thêm"), systemImage: "plus") { completingID = nil; draft = VaccinationRecord() }
                    .disabled(baby == nil || !viewModel.state.vaccinationsAvailable).accessibilityIdentifier("addVaccinationButton")
            }
        }
        .sheet(item: $draft) { record in
            NavigationStack { VaccinationEntryView(record: record, babyID: babyID, completingID: completingID) }
        }
        .alert(L10n.text("Xóa mũi tiêm và lịch nhắc?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(L10n.text("Hủy"), role: .cancel) { deleting = nil }
            Button(L10n.text("Xóa"), role: .destructive) {
                guard let record = deleting else { return }
                Task {
                    if await viewModel.send(.commit(.deleteVaccination(babyID: babyID, vaccinationID: record.id), message: L10n.text("Đã xóa mũi tiêm"))) { deleting = nil }
                }
            }
        }
    }
}

struct VaccinationEntryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State var record: VaccinationRecord
    let babyID: UUID
    var completingID: UUID?
    @State private var original: VaccinationRecord?
    @State private var confirmDiscard = false
    private var baby: BabyData? { viewModel.state.database.babies.first { $0.profile.id == babyID } }
    private var valid: Bool {
        guard viewModel.state.vaccinationsAvailable, let baby else { return false }
        return (try? CareValidation.vaccination(record, birthDate: baby.profile.birthDate)) != nil
    }
    private var dirty: Bool { original.map { $0 != record } ?? false }
    var body: some View {
        Form {
            Section(L10n.text("Mũi đã tiêm")) {
                TextField(L10n.text("Tên vắc xin"), text: $record.vaccineName).accessibilityIdentifier("vaccineNameField")
                DatePicker(L10n.text("Ngày tiêm"), selection: $record.date, in: (baby?.profile.birthDate ?? .distantPast)...Date())
                Stepper(L10n.text("Mũi {0}", String(record.doseNumber)), value: $record.doseNumber, in: 1...1000)
                TextField(L10n.text("Phòng khám / Bệnh viện"), text: $record.clinic)
                TextField(L10n.text("Ghi chú"), text: $record.notes, axis: .vertical).lineLimit(3...6)
            }
            Section(L10n.text("Lịch mũi tiếp theo")) {
                Toggle(L10n.text("Có lịch hẹn tiếp theo"), isOn: Binding(get: { record.nextDoseDate != nil }, set: { enabled in
                    record.nextDoseDate = enabled ? max(Date(), record.date).addingTimeInterval(30 * 86400) : nil
                    if !enabled { record.reminderEnabled = false; record.reminderDate = nil }
                }))
                if record.nextDoseDate != nil {
                    DatePicker(L10n.text("Mũi tiếp theo"), selection: Binding(get: { record.nextDoseDate ?? Date() }, set: { record.nextDoseDate = $0 }))
                    Toggle(L10n.text("Nhắc trước mũi tiếp theo"), isOn: Binding(get: { record.reminderEnabled }, set: { enabled in
                        record.reminderEnabled = enabled
                        if !enabled { record.reminderDate = nil }
                        if enabled && record.reminderDate == nil { record.reminderDate = record.nextDoseDate?.addingTimeInterval(-86400) }
                    }))
                    if record.reminderEnabled {
                        DatePicker(L10n.text("Thời điểm nhắc"), selection: Binding(get: { record.reminderDate ?? Date() }, set: { record.reminderDate = $0 }))
                        if let reminder = record.reminderDate, reminder <= Date() {
                            Text(L10n.text("Thời điểm nhắc đã qua; lịch vẫn được lưu nhưng không gửi thông báo cũ.")).font(CareFont.footnote)
                        }
                    }
                }
            }
            if !valid { Text(L10n.text("Thông tin tiêm chủng hoặc lịch nhắc không hợp lệ.")).foregroundStyle(CareTheme.medical) }
            if let error = viewModel.state.error { Text(error).foregroundStyle(CareTheme.medical) }
        }
        .navigationTitle(L10n.text("Thông tin tiêm chủng"))
        .navigationSubtitle(baby?.profile.name ?? "")
        .onAppear { if original == nil { original = record } }
        .interactiveDismissDisabled(dirty || viewModel.state.isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("Hủy")) { if dirty { confirmDiscard = true } else { dismiss() } }.disabled(viewModel.state.isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.text("Lưu")) {
                    let saved = record
                    Task {
                        if await viewModel.send(.commit(.saveVaccination(babyID: babyID, record: saved, completingID: completingID), message: L10n.text("Đã lưu mũi tiêm"))) { dismiss() }
                    }
                }.disabled(!valid || viewModel.state.isSaving).accessibilityIdentifier("saveVaccinationButton")
            }
        }
        .confirmationDialog(L10n.text("Bỏ nội dung chưa lưu?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L10n.text("Bỏ nội dung"), role: .destructive) { dismiss() }
        }
    }
}
