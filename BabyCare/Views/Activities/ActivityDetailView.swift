import SwiftUI

/// Stitch E — native view backed by the existing data provider.
struct ActivityDetailView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let activity: CareActivity
    @State private var deleting = false
    @State private var editing = false
    @State private var recordingAgain = false
    private var current: CareActivity { viewModel.activities.first { $0.id == activity.id } ?? activity }

    var body: some View {
        ScrollView {
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
                            CareBadge(title: "Đã ghi")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(current.kind == .temperature ? "NHIỆT ĐỘ CƠ THỂ" : "NỘI DUNG GHI NHẬN")
                                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            Text(current.formattedValue).font(CareFont.largeTitle.bold()).foregroundStyle(current.kind.group.color)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(current.kind.group.background.opacity(0.6), in: .rect(cornerRadius: 14))
                        LabeledContent("Đối tượng", value: "\(viewModel.baby.name) · \(viewModel.baby.ageDescription)").font(CareFont.subheadline)
                        if !current.detail.isEmpty { LabeledContent("Thông tin thêm", value: current.detail).font(CareFont.subheadline) }
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CareSectionTitle(title: "Ghi chú")
                        Text(current.note.isEmpty ? "Chưa có ghi chú" : current.note)
                            .font(CareFont.body).foregroundStyle(CareTheme.secondary)
                        if !current.attachments.isEmpty {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(Array(current.attachments.enumerated()), id: \.offset) { index, data in
                                        #if canImport(UIKit)
                                        if let image = CareImageProcessor.thumbnail(data, maximumPixels: 1200) {
                                            Image(uiImage: image).resizable().scaledToFit().frame(width: 220, height: 200)
                                                .clipShape(.rect(cornerRadius: 12)).accessibilityLabel("Ảnh đính kèm \(index + 1)")
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
                    Label("Sửa hoạt động", systemImage: "pencil").font(CareFont.headline).frame(maxWidth: .infinity, minHeight: 40)
                }.buttonStyle(.bordered)
                CarePrimaryButton(title: current.kind == .temperature ? "Ghi tương tự (Đo lại bây giờ)" : "Ghi tương tự") { recordingAgain = true }
                Button("Xóa hoạt động này", role: .destructive) { deleting = true }
                    .frame(maxWidth: .infinity, minHeight: 48)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen().navigationTitle("Chi tiết hoạt động").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $editing) { NavigationStack { ActivityFormView(kind: current.kind, activity: current) } }
        .sheet(isPresented: $recordingAgain) {
            NavigationStack {
                ActivityFormView(kind: current.kind, activity: repeatedEntry)
            }
        }
        .alert("Xóa \(current.kind.title.lowercased())?", isPresented: $deleting) {
            Button("Hủy", role: .cancel) { }
            Button("Xóa", role: .destructive) {
                Task {
                    guard await viewModel.send(.commit(.deleteActivity(babyID: viewModel.baby.id, activityID: current.id), message: "Đã xóa hoạt động")) else { return }
                    dismiss()
                }
            }
        } message: { Text("Hoạt động này sẽ được bỏ khỏi nhật ký và thống kê.") }
    }

    private var repeatedEntry: CareActivity {
        CareActivity(kind: current.kind, value: current.kind == .temperature ? "" : current.value,
            unit: current.unit, detail: current.detail)
    }
}
#Preview { NavigationStack { ActivityDetailView(activity: BabyCareViewModel.preview().activities[0]) }.environment(BabyCareViewModel.preview()) }
