import SwiftUI

/// Stitch C: a featured action followed by a two-column activity grid.
struct ActivityPickerView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selectedGroup: ActivityGroup
    @State private var gridSpan: ClosedRange<CGFloat> = 0...0
    @Environment(\.careWindow) private var window
    init(initialGroup: ActivityGroup = .medical) { _selectedGroup = State(initialValue: initialGroup) }
    private var kinds: [ActivityKind] { ActivityKind.allCases.filter { $0.group == selectedGroup } }

    /// Two equal columns, except on the open iPhone Duo: the sheet sits across the hinge, so the column gap
    /// widens to cover it and no tile lands on the fold.
    private var gridColumns: [GridItem] {
        if textSize.isAccessibilitySize { return [GridItem(.flexible(), spacing: 10)] }
        if let fold = window.localFold(in: gridSpan) {
            let gutter = fold.upperBound - fold.lowerBound + 2 * CareColumnsPlan.foldClearance
            let leading = (fold.lowerBound + fold.upperBound) / 2 - gutter / 2
            let trailing = gridSpan.upperBound - gridSpan.lowerBound - leading - gutter
            if leading >= 140, trailing >= 140 { return [GridItem(.fixed(leading), spacing: gutter), GridItem(.fixed(trailing))] }
        }
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text("Ghi hoạt động cho {0}", "\(viewModel.baby.name)")).font(CareFont.title2.bold())
                        Text(L10n.text("Chọn danh mục hoặc nói để ghi nhanh")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        CareIcon(name: "Stitch_close", color: CareTheme.secondary, size: 22)
                            .frame(width: 36, height: 36).background(CareTheme.background, in: .circle)
                    }.buttonStyle(.plain).accessibilityLabel(L10n.text("Đóng"))
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
                    Text(selectedGroup == .medical ? L10n.text("SỨC KHỎE & TRIỆU CHỨNG BÉ") : selectedGroup.title.uppercased()).foregroundStyle(selectedGroup.color)
                    Spacer()
                    Text(L10n.text("{0} mục theo dõi", "\(kinds.count)")).foregroundStyle(CareTheme.secondary)
                }.font(CareFont.caption)
                if selectedGroup == .medical {
                    NavigationLink { ActivityFormView(kind: .temperature) } label: {
                        HStack(spacing: 14) {
                            CareIcon(name: ActivityKind.temperature.assetName, color: CareTheme.medical, size: 30)
                                .frame(width: 48, height: 48).background(.white, in: .rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.text("Nhiệt độ")).font(CareFont.headline)
                                Text(ActivityKind.temperature.entrySubtitle).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            CareIcon(name: "Stitch_chevron_right", color: CareTheme.medical, size: 22)
                        }.padding(16).background(CareTheme.medicalBackground, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.medical.opacity(0.25)))
                    }.buttonStyle(.plain).accessibilityIdentifier("picker.kind.temperature")
                }
                LazyVGrid(columns: gridColumns, spacing: 10) {
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
                        }.buttonStyle(.plain).accessibilityIdentifier("picker.kind.\(kind.rawValue)")
                    }
                }.careHorizontalSpan($gridSpan)
                NavigationLink { VoiceEntryView() } label: {
                    HStack(spacing: 14) {
                        CareIcon(name: "Stitch_mic", color: .white, size: 30)
                            .frame(width: 52, height: 52).background(CareTheme.accent, in: .rect(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 6) {
                            Label { Text(L10n.text("Nói để ghi")).font(CareFont.headline) } icon: {
                                CareIcon(name: "Stitch_auto_awesome", color: CareTheme.accent, size: 18)
                            }
                            Text(L10n.text("Nói rõ hoạt động, app tự lưu khi nhận dạng đúng.")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
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
        case .temperature: L10n.text("Ghi số đo và vị trí đo")
        case .breathing: L10n.text("Đếm số nhịp thở trong 1 phút")
        case .medicine: L10n.text("Tên hoặc ảnh thuốc, lượng dùng")
        case .symptom: L10n.text("Ghi biểu hiện của bé")
        case .doctor: L10n.text("Lý do khám và lời dặn")
        case .allergy: L10n.text("Tác nhân, mức độ và độ chắc chắn")
        case .milk: L10n.text("Bú mẹ, sữa vắt hoặc sữa công thức")
        case .meal: L10n.text("Thực phẩm và số lượng nếu muốn")
        case .water: L10n.text("Lượng nước bé đã uống")
        case .sleep: L10n.text("Giờ bắt đầu và kết thúc")
        case .bath: L10n.text("Ghi nhanh lần tắm cho bé")
        case .diaper: L10n.text("Thay tã, đi tiểu hoặc đi ngoài")
        case .other: L10n.text("Hoạt động khác trong ngày")
        }
    }
}

#Preview {
    NavigationStack { ActivityPickerView() }
        .environment(BabyCareViewModel.preview())
}
