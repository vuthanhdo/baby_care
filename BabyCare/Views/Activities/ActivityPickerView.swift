import SwiftUI

/// Stitch C: a featured action followed by a two-column activity grid.
struct ActivityPickerView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selectedGroup: ActivityGroup
    init(initialGroup: ActivityGroup = .medical) { _selectedGroup = State(initialValue: initialGroup) }
    private var kinds: [ActivityKind] { ActivityKind.allCases.filter { $0.group == selectedGroup } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ghi hoạt động cho \(viewModel.baby.name)").font(CareFont.title2.bold())
                        Text("Chọn danh mục hoặc nói để ghi nhanh").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        CareIcon(name: "Stitch_close", color: CareTheme.secondary, size: 22)
                            .frame(width: 36, height: 36).background(CareTheme.background, in: .circle)
                    }.buttonStyle(.plain).accessibilityLabel("Đóng")
                }
                HStack(spacing: 4) {
                    ForEach(ActivityGroup.allCases) { group in
                        Button { selectedGroup = group } label: {
                            VStack(spacing: 5) {
                                CareIcon(name: group.assetName, color: selectedGroup == group ? group.color : CareTheme.secondary, size: 22)
                                Text(group.title).font(CareFont.callout)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                                .foregroundStyle(selectedGroup == group ? group.color : CareTheme.secondary)
                                .background(selectedGroup == group ? group.background : .clear, in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selectedGroup == group ? group.color.opacity(0.25) : .clear))
                        }.buttonStyle(.plain).accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                            .accessibilityIdentifier("picker.group.\(group.rawValue)")
                    }
                }.padding(4).background(CareTheme.background, in: .rect(cornerRadius: 16))
                HStack {
                    Text(selectedGroup == .medical ? "SỨC KHỎE & TRIỆU CHỨNG BÉ" : selectedGroup.title.uppercased()).foregroundStyle(selectedGroup.color)
                    Spacer()
                    Text("\(kinds.count) mục theo dõi").foregroundStyle(CareTheme.secondary)
                }.font(CareFont.caption)
                if selectedGroup == .medical {
                    NavigationLink { ActivityFormView(kind: .temperature) } label: {
                        HStack(spacing: 14) {
                            CareIcon(name: ActivityKind.temperature.assetName, color: CareTheme.medical, size: 30)
                                .frame(width: 48, height: 48).background(.white, in: .rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nhiệt độ").font(CareFont.headline)
                                Text(ActivityKind.temperature.entrySubtitle).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            CareIcon(name: "Stitch_chevron_right", color: CareTheme.medical, size: 22)
                        }.padding(16).background(CareTheme.medicalBackground, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.medical.opacity(0.25)))
                    }.buttonStyle(.plain)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                    ForEach(kinds.filter { selectedGroup != .medical || $0 != .temperature }) { kind in
                        NavigationLink { ActivityFormView(kind: kind) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                CareIcon(name: kind.assetName, color: tileColor(kind), size: 26)
                                    .frame(width: 42, height: 42).background(tileColor(kind).opacity(0.1), in: .rect(cornerRadius: 12))
                                Text(kind.title).font(CareFont.headline)
                                Text(kind.entrySubtitle).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading).padding(16)
                                .background(CareTheme.background, in: .rect(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.border))
                        }.buttonStyle(.plain)
                    }
                }
                NavigationLink { VoiceEntryView() } label: {
                    HStack(spacing: 14) {
                        CareIcon(name: "Stitch_mic", color: .white, size: 30)
                            .frame(width: 52, height: 52).background(CareTheme.accent, in: .rect(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 6) {
                            Label { Text("Nói để ghi").font(CareFont.headline) } icon: {
                                CareIcon(name: "Stitch_auto_awesome", color: CareTheme.accent, size: 18)
                            }
                            Text("Nói rõ hoạt động, app tự lưu khi nhận dạng đúng.").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareTheme.accent.opacity(0.06), in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.accent.opacity(0.2)))
                }.buttonStyle(.plain)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .background(CareTheme.surface).foregroundStyle(CareTheme.text)
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private func tileColor(_ kind: ActivityKind) -> Color {
        switch kind {
        case .medicine: CareTheme.feeding
        case .doctor: CareTheme.accent
        case .allergy: CareTheme.routine
        default: kind.group.color
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
