import SwiftUI

enum CareTheme {
    static let background = Color("CareBackground")
    static let surface = Color("CareSurface")
    static let text = Color("CareText")
    static let secondary = Color("CareSecondary")
    static let accent = Color.accentColor
    static let border = Color("CareBorder")
    static let medical = Color("CareMedical")
    static let medicalBackground = Color("CareMedicalBackground")
    static let feeding = Color("CareFeeding")
    static let feedingBackground = Color("CareFeedingBackground")
    static let routine = Color("CareRoutine")
    static let routineBackground = Color("CareRoutineBackground")
}

struct CareCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(CareTheme.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CareTheme.border, lineWidth: 1))
            .shadow(color: CareTheme.text.opacity(0.035), radius: 8, y: 2)
    }
}

struct CareIcon: View {
    let name: String
    var color: Color = CareTheme.accent
    var size: CGFloat = 22
    var body: some View {
        Image(name).resizable().renderingMode(.template).scaledToFit()
            .foregroundStyle(color).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CarePrimaryButton: View {
    let title: String
    var color: Color = CareTheme.accent
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { CareIcon(name: icon, color: .white, size: 22) }
                Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }.buttonStyle(CareActionStyle(color: color))
    }
}

struct CareSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(CareFont.headline).foregroundStyle(CareTheme.text)
            if let subtitle { Text(subtitle).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CareBadge: View {
    let title: String
    var color: Color = CareTheme.accent
    var body: some View {
        Text(title).font(CareFont.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.09), in: .capsule)
    }
}

struct CareActivityRow: View {
    let activity: CareActivity
    var body: some View {
        HStack(spacing: 12) {
            CareIcon(name: activity.kind.assetName, color: activity.kind.group.color)
                .frame(width: 44, height: 44)
                .background(activity.kind.group.background, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.kind.title).font(CareFont.subheadline.weight(.semibold))
                Text(activity.formattedValue.isEmpty ? activity.note : activity.formattedValue)
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(activity.date, format: .dateTime.hour().minute())
                .font(CareFont.caption.monospacedDigit()).foregroundStyle(CareTheme.secondary)
        }.foregroundStyle(CareTheme.text).padding(.vertical, 4)
    }
}

struct CareBabyHeaderView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink { BabyProfileView() } label: {
                HStack(spacing: 10) {
                    ProfileAvatarView(name: viewModel.baby.name, imageData: viewModel.baby.avatarData, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.baby.name).font(CareFont.headline).foregroundStyle(CareTheme.text)
                        Text(viewModel.baby.ageDescription).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                }
            }.buttonStyle(.plain).accessibilityLabel("Hồ sơ \(viewModel.baby.name)")
            if viewModel.babies.count > 1 {
                Menu {
                    ForEach(viewModel.babies) { baby in
                        Button(baby.name) { Task { await viewModel.send(.commit(.selectBaby(baby.id))) } }
                    }
                } label: { Image(systemName: "chevron.down").font(CareFont.caption) }
                .accessibilityLabel("Chọn bé")
            }
            Spacer()
            NavigationLink { SettingsView() } label: {
                CareIcon(name: "Stitch_settings", color: CareTheme.text, size: 24)
            }.buttonStyle(.plain).frame(width: 48, height: 48)
                .background(CareTheme.surface, in: .circle)
                .overlay(Circle().strokeBorder(CareTheme.border)).accessibilityLabel("Cài đặt")
            NavigationLink { IllnessTrackingView() } label: {
                CareIcon(name: "Stitch_notifications", color: CareTheme.text, size: 24)
            }.buttonStyle(.plain).frame(width: 48, height: 48)
                .background(CareTheme.surface, in: .circle)
                .overlay(Circle().strokeBorder(CareTheme.border)).accessibilityLabel("Theo dõi và lịch nhắc")
        }.padding(.horizontal, 20).padding(.vertical, 8)
            .background(CareTheme.background)
            .overlay(alignment: .bottom) { Rectangle().fill(CareTheme.border).frame(height: 0.5) }
    }
}

extension View {
    func careScreen() -> some View {
        self.scrollContentBackground(.hidden).background(CareTheme.background)
    }
}

extension Date {
    func careFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(Locale(identifier: "vi_VN")))
    }
}

extension ActivityGroup {
    var color: Color {
        switch self { case .medical: CareTheme.medical; case .feeding: CareTheme.feeding; case .routine: CareTheme.routine }
    }
    var background: Color {
        switch self { case .medical: CareTheme.medicalBackground; case .feeding: CareTheme.feedingBackground; case .routine: CareTheme.routineBackground }
    }
}
