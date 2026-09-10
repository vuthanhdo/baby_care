import SwiftUI

/// Stitch C — grouped activity choices inside a native sheet.
struct ActivityPickerView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroup: ActivityGroup
    init(initialGroup: ActivityGroup = .medical) { _selectedGroup = State(initialValue: initialGroup) }
    private var kinds: [ActivityKind] { ActivityKind.allCases.filter { $0.group == selectedGroup } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CareSectionTitle(title: "Ghi hoạt động cho \(viewModel.baby.name)", subtitle: "Chọn danh mục để ghi lại việc chăm bé.")
                Picker("Nhóm hoạt động", selection: $selectedGroup) {
                    Text("Y tế").tag(ActivityGroup.medical)
                    Text("Ăn uống").tag(ActivityGroup.feeding)
                    Text("Sinh hoạt").tag(ActivityGroup.routine)
                }.pickerStyle(.segmented)
                HStack {
                    Text(selectedGroup.title.uppercased()).tracking(1)
                    Spacer()
                    Text("\(kinds.count) mục theo dõi")
                }.font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                CareCard {
                    VStack(spacing: 0) {
                        ForEach(kinds, id: \.self) { kind in
                            NavigationLink { ActivityFormView(kind: kind) } label: {
                                HStack(spacing: 14) {
                                    CareIcon(name: kind.assetName, color: selectedGroup.color, size: 24)
                                        .frame(width: 48, height: 48)
                                        .background(selectedGroup.background, in: .rect(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(kind.title).font(CareFont.headline).foregroundStyle(CareTheme.text)
                                        Text(kind.entrySubtitle).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(selectedGroup.color)
                                }.padding(.vertical, 14)
                            }.buttonStyle(.plain)
                            if kind != kinds.last { Divider().overlay(CareTheme.border) }
                        }
                    }
                }
                NavigationLink { VoiceEntryView() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "mic.fill").font(.system(size: 24)).foregroundStyle(.white)
                            .frame(width: 52, height: 52).background(CareTheme.accent, in: .circle)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nói để ghi").font(CareFont.headline)
                            Text("Nhập nội dung và xem lại trước khi lưu").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareTheme.accent.opacity(0.06), in: .rect(cornerRadius: 16))
                }.buttonStyle(.plain)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen().navigationTitle("Chọn hoạt động").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Đóng", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
            }
        }
    }
}

extension ActivityKind {
    var entrySubtitle: String {
        switch self {
        case .temperature: "Ghi số đo và vị trí đo"
        case .medicine: "Tên thuốc và lượng đã dùng"
        case .symptom: "Ghi biểu hiện của bé"
        case .doctor: "Lý do khám và lời dặn"
        case .allergy: "Biểu hiện và tác nhân nếu biết"
        case .milk: "Bú mẹ, sữa vắt hoặc sữa công thức"
        case .meal: "Món ăn và lượng bé đã ăn"
        case .water: "Lượng nước bé đã uống"
        case .sleep: "Giờ bắt đầu và kết thúc"
        case .bath: "Ghi nhanh lần tắm cho bé"
        case .diaper: "Thay tã, đi tiểu hoặc đi ngoài"
        case .other: "Hoạt động khác trong ngày"
        }
    }
}

#Preview {
    NavigationStack { ActivityPickerView() }
        .environment(BabyCareViewModel.preview())
}
