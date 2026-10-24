import SwiftUI

/// Stitch E — native view backed by the existing data provider.
struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let activity: CareActivity

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            ActivityDetailContent(activity: activity) { dismiss() }
                .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen().navigationTitle(L10n.text("Chi tiết hoạt động")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
    }
}

/// Cards and actions of one activity. Shared by the pushed detail screen and the diary's detail pane,
/// which sits beside the list on the open iPhone Duo and on iPad.
struct ActivityDetailContent: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    let activity: CareActivity
    /// Called after the activity was deleted: the screen pops, the pane clears its selection.
    var onDeleted: () -> Void
    @State private var deleting = false
    @State private var editing = false
    @State private var recordingAgain = false
    private var current: CareActivity { viewModel.activities.first { $0.id == activity.id } ?? activity }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 18) {
            CareCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        CareIcon(name: current.kind.assetName, color: current.kind.group.color)
                            .frame(width: 44, height: 44).background(current.kind.group.background, in: .circle)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(current.kind.title).font(CareFont.headline).foregroundStyle(current.kind.group.color)
                            Text(current.date, format: .dateTime.hour().minute().day().month().year())
                                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                        Spacer(minLength: 0)
                        CareBadge(title: L10n.text("Đã ghi"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.kind == .temperature ? L10n.text("NHIỆT ĐỘ CƠ THỂ") : current.kind == .breathing ? L10n.text("NHỊP THỞ") : L10n.text("NỘI DUNG GHI NHẬN"))
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        Text(current.kind == .doctor ? current.value : current.formattedValue).font(CareFont.largeTitle.bold()).foregroundStyle(current.kind.group.color)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(current.kind.group.background.opacity(0.6), in: .rect(cornerRadius: 14))
                    LabeledContent(L10n.text("Đối tượng"), value: "\(viewModel.baby.name) · \(viewModel.baby.ageDescription)").font(CareFont.subheadline)
                    if !DoctorVisit.diagnosis(current).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("Chẩn đoán của bác sĩ")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            Text(DoctorVisit.diagnosis(current)).font(CareFont.subheadline.weight(.semibold))
                        }
                    }
                    if !current.detail.isEmpty {
                        if current.kind == .doctor {
                            // Advice is usually several sentences; it reads better under its label than squeezed beside it.
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.text("Lời dặn của bác sĩ")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                Text(current.detail).font(CareFont.subheadline)
                            }
                        } else {
                            LabeledContent(L10n.text("Thông tin thêm"), value: current.displayDetail).font(CareFont.subheadline)
                        }
                    }
                    if let followUp = current.followUpDate {
                        LabeledContent(L10n.text("Lịch khám lại"), value: followUp.careFormatted(date: .abbreviated, time: .shortened)).font(CareFont.subheadline)
                    }
                }
            }
            CareCard {
                VStack(alignment: .leading, spacing: 12) {
                    CareSectionTitle(title: L10n.text("Ghi chú"))
                    Text(current.note.isEmpty ? L10n.text("Chưa có ghi chú") : current.note)
                        .font(CareFont.body).foregroundStyle(CareTheme.secondary)
                    if !current.attachments.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Array(current.attachments.enumerated()), id: \.offset) { index, data in
                                    #if canImport(UIKit)
                                    if let image = CareImageProcessor.thumbnail(data, maximumPixels: 1200) {
                                        Image(uiImage: image).resizable().scaledToFit().frame(width: 220, height: 200)
                                            .clipShape(.rect(cornerRadius: 12)).accessibilityLabel(L10n.text("Ảnh đính kèm {0}", "\(index + 1)"))
                                    }
                                    #endif
                                }
                            }
                        }
                    }
                }
            }
            if current.kind == .temperature {
                CareCard {
                    TemperatureChartView(activities: viewModel.activities.filter { Calendar.current.isDate($0.date, inSameDayAs: current.date) }, compact: true)
                }
            }
            Button { editing = true } label: {
                Label { Text(L10n.text("Sửa hoạt động")) } icon: { CareIcon(name: "Stitch_edit", color: .white) }
            }.buttonStyle(CareActionStyle())
            CarePrimaryButton(title: current.kind == .temperature ? L10n.text("Ghi tương tự (Đo lại bây giờ)") : L10n.text("Ghi tương tự"), icon: "Stitch_add_circle") { recordingAgain = true }
            Button(role: .destructive) { deleting = true } label: {
                HStack { CareIcon(name: "Stitch_delete", color: CareTheme.medical); Text(L10n.text("Xóa hoạt động này")) }
            }
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .sheet(isPresented: $editing) { NavigationStack { ActivityFormView(kind: current.kind, activity: current) } }
        .sheet(isPresented: $recordingAgain) {
            NavigationStack {
                ActivityFormView(kind: current.kind, activity: repeatedEntry)
            }
        }
        .alert(L10n.text("Xóa {0}?", "\(current.kind.title.lowercased())"), isPresented: $deleting) {
            Button(L10n.text("Hủy"), role: .cancel) { }
            Button(L10n.text("Xóa"), role: .destructive) {
                Task {
                    guard await viewModel.send(.commit(.deleteActivity(babyID: viewModel.baby.id, activityID: current.id), message: L10n.text("Đã xóa hoạt động"))) else { return }
                    onDeleted()
                }
            }
        } message: { Text(L10n.text("Hoạt động này sẽ được bỏ khỏi nhật ký và thống kê.")) }
    }

    private var repeatedEntry: CareActivity {
        // A repeated sleep keeps its length and ends now, so it never starts out in the future.
        let minutes = current.kind == .sleep && current.detail != CareActivity.recordedSleepDetail ? current.numericValue : nil
        return CareActivity(kind: current.kind, date: Date().addingTimeInterval(-(minutes ?? 0) * 60),
            value: [.temperature, .breathing].contains(current.kind) ? "" : current.value, unit: current.unit, detail: current.detail)
    }
}
#Preview { NavigationStack { ActivityDetailView(activity: BabyCareViewModel.preview().activities[0]) }.environment(BabyCareViewModel.preview()) }
