import SwiftUI

/// Typography from the Stitch “Bé Khỏe” design system. Custom fonts scale with Dynamic Type.
enum CareFont {
    static let largeTitle = Font.custom("BeVietnamPro-Bold", size: 28, relativeTo: .largeTitle)
    static let title = Font.custom("BeVietnamPro-Bold", size: 24, relativeTo: .title)
    static let title2 = Font.custom("BeVietnamPro-SemiBold", size: 20, relativeTo: .title2)
    static let title3 = Font.custom("BeVietnamPro-SemiBold", size: 18, relativeTo: .title3)
    static let headline = Font.custom("BeVietnamPro-SemiBold", size: 17, relativeTo: .headline)
    static let body = Font.custom("BeVietnamPro-Regular", size: 17, relativeTo: .body)
    static let subheadline = Font.custom("BeVietnamPro-Regular", size: 15, relativeTo: .subheadline)
    static let callout = Font.custom("BeVietnamPro-Medium", size: 14, relativeTo: .callout)
    static let footnote = Font.custom("BeVietnamPro-Regular", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("BeVietnamPro-Medium", size: 12, relativeTo: .caption)
    static let caption2 = Font.custom("BeVietnamPro-Medium", size: 11, relativeTo: .caption2)
}

struct CareActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var color: Color = CareTheme.accent
    var outlined = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CareFont.headline)
            .foregroundStyle(outlined ? color : .white)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(outlined ? CareTheme.surface : color, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(outlined ? color.opacity(0.35) : .clear))
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct CareBrandView: View {
    var size: CGFloat = 88
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Image("BeKhoeLogo").resizable().scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2))
            .shadow(color: CareTheme.accent.opacity(0.1), radius: 12, y: 4)
            .accessibilityLabel(L10n.text("Logo Bé Khỏe"))
    }
}

struct CareSplashView: View {
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        // The logo sits exactly where the launch screen draws LaunchLogo (centre of the whole screen), so the
        // hand-over from the system launch screen to this view does not move it.
        CareBrandView(size: 160)
            .overlay(alignment: .top) {
                VStack(spacing: 20) {
                    Text(L10n.text("Bé Khỏe")).font(CareFont.largeTitle).foregroundStyle(CareTheme.accent)
                    Text(L10n.text("Bố Mẹ An Tâm")).font(CareFont.title3)
                    Text(L10n.text("Ghi nhanh nhật ký · Theo dõi sát sao\nĐồng hành cùng bé yêu"))
                        .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                        .multilineTextAlignment(.center)
                }.fixedSize().offset(y: 180)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                ProgressView(L10n.text("Đang chuẩn bị dữ liệu…")).font(CareFont.footnote).padding(.bottom, 32)
            }
            .background(CareTheme.background).accessibilityIdentifier("care.splash")
    }
}

struct CareInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.padding(14).frame(minHeight: 52)
            .background(CareTheme.surface, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
    }
}

struct CareFormCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                if let title { Text(title).font(CareFont.headline) }
                content
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Keeps the form compact; dates are edited as a draft until the user applies them.
struct CareDateTimeField: View {
    var title = L10n.text("Thời điểm")
    @Binding var selection: Date
    var earliest: Date = .distantPast
    @State private var showingPicker = false
    @State private var draft = Date()

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "clock").font(CareFont.headline)
                Spacer()
                Button(L10n.text("Bây giờ"), systemImage: "arrow.clockwise") { selection = Date() }
                    .font(CareFont.caption).padding(.horizontal, 10).frame(minHeight: 44)
                    .background(CareTheme.accent.opacity(0.07), in: .capsule)
            }
            Button { draft = selection; showingPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar").foregroundStyle(CareTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection, format: .dateTime.hour().minute()).font(CareFont.headline)
                        Text(selection.careFormatted(date: .abbreviated, time: .omitted))
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12))
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CareTheme.background, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
            }.buttonStyle(.plain).accessibilityLabel(L10n.text("Chọn ") + title.lowercased())
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                Form {
                    DatePicker(title, selection: $draft, in: min(earliest, Date.now)...Date.now, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    DatePicker(L10n.text("Giờ"), selection: $draft, in: min(earliest, Date.now)...Date.now, displayedComponents: .hourAndMinute)
                }.careScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { showingPicker = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.text("Áp dụng")) { selection = draft; showingPicker = false }
                        }
                    }
            }.presentationDetents([.large])
        }
    }
}
