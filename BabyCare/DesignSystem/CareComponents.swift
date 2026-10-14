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
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
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
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Image(name).resizable().renderingMode(.template).scaledToFit()
            .foregroundStyle(color).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CarePrimaryButton: View {
    let title: String
    var color: Color = CareTheme.accent
    var icon: String? = nil
    var isLoading = false
    let action: () -> Void
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(.white) }
                else if let icon { CareIcon(name: icon, color: .white, size: 22) }
                Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }.buttonStyle(CareActionStyle(color: color))
            .disabled(isLoading)
            .accessibilityValue(isLoading ? L10n.text("Đang xử lý") : "")
    }
}

struct CareSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(CareFont.headline).foregroundStyle(CareTheme.text)
            if let subtitle { Text(subtitle).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CareBadge: View {
    let title: String
    var color: Color = CareTheme.accent
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Text(title).font(CareFont.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.09), in: .capsule)
    }
}

struct CareActivityRow: View {
    let activity: CareActivity
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
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
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        HStack(spacing: 12) {
            NavigationLink { BabyProfileView() } label: {
                HStack(spacing: 10) {
                    ProfileAvatarView(name: viewModel.baby.name, imageData: viewModel.baby.avatarData, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.baby.name).font(CareFont.headline).foregroundStyle(CareTheme.text)
                        Text(viewModel.baby.ageDescription).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                }
            }.buttonStyle(.plain).accessibilityLabel(L10n.text("Hồ sơ {0}", "\(viewModel.baby.name)"))
            if viewModel.babies.count > 1 {
                Menu {
                    ForEach(viewModel.babies) { baby in
                        Button(baby.name) { Task { await viewModel.send(.commit(.selectBaby(baby.id))) } }
                    }
                } label: { Image(systemName: "chevron.down").font(CareFont.caption) }
                .accessibilityLabel(L10n.text("Chọn bé"))
            }
            Spacer()
            NavigationLink { SettingsView() } label: {
                CareIcon(name: "Stitch_settings", color: CareTheme.text, size: 24)
            }.buttonStyle(.plain).frame(width: 48, height: 48)
                .background(CareTheme.surface, in: .circle)
                .overlay(Circle().strokeBorder(CareTheme.border)).accessibilityLabel(L10n.text("Cài đặt")).accessibilityIdentifier("app.settings")
            NavigationLink { IllnessTrackingView() } label: {
                CareIcon(name: "Stitch_notifications", color: CareTheme.text, size: 24)
            }.buttonStyle(.plain).frame(width: 48, height: 48)
                .background(CareTheme.surface, in: .circle)
                .overlay(Circle().strokeBorder(CareTheme.border)).accessibilityLabel(L10n.text("Theo dõi và lịch nhắc"))
        }.padding(.horizontal, 20).padding(.vertical, 8)
            .background(CareTheme.background)
            .overlay(alignment: .bottom) { Rectangle().fill(CareTheme.border).frame(height: 0.5) }
    }
}

extension View {
    func careScreen() -> some View {
        self.scrollContentBackground(.hidden).background(CareTheme.background)
    }
    /// Shows `BabyCareViewModel.toast` as a top banner. Attach to the app content and to any sheet that stays
    /// open after a save, because a presented sheet hides the banner of the view underneath it.
    func careToastBanner() -> some View { modifier(CareToastBanner()) }
}

/// A banner only covers static chrome, never the entry that was just saved; taps pass through it.
struct CareToastBanner: ViewModifier {
    @Environment(BabyCareViewModel.self) private var viewModel
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ZStack(alignment: .top) {
                if let toast = viewModel.toast {
                    Text(toast).font(CareFont.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 12).foregroundStyle(.white)
                        .background(CareTheme.text, in: .capsule)
                        .shadow(color: CareTheme.text.opacity(0.18), radius: 10, y: 4)
                        .padding(.horizontal, 20).padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .animation(.snappy, value: viewModel.toast)
            .allowsHitTesting(false)
        }
    }
}

extension Date {
    func careFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(AppLanguage.current.locale))
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

/// Keeps progress local to the button whose asynchronous action is running.
struct CareAsyncButton: View {
    let title: String
    var role: ButtonRole? = nil
    let action: @MainActor () async -> Void
    @State private var isLoading = false

    init(_ title: String, role: ButtonRole? = nil, action: @escaping @MainActor () async -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Button(role: role) {
            guard !isLoading else { return }
            isLoading = true
            Task { @MainActor in
                defer { isLoading = false }
                await action()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading { ProgressView() }
                Text(title)
            }
        }
        .disabled(isLoading)
        .accessibilityValue(isLoading ? L10n.text("Đang xử lý") : "")
    }
}
