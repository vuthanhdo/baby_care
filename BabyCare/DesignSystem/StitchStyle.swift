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
    var body: some View {
        Image("BeKhoeLogo").resizable().scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2))
            .shadow(color: CareTheme.accent.opacity(0.1), radius: 12, y: 4)
            .accessibilityLabel("Logo Bé Khỏe")
    }
}

struct CareSplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            CareBrandView(size: 160)
            Text("Bé Khỏe").font(CareFont.largeTitle).foregroundStyle(CareTheme.accent)
            Text("Bố Mẹ An Tâm").font(CareFont.title3)
            Text("Ghi nhanh nhật ký · Theo dõi sát sao\nĐồng hành cùng bé yêu")
                .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            ProgressView("Đang chuẩn bị dữ liệu…").font(CareFont.footnote)
            Spacer().frame(height: 32)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
    var body: some View {
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
    var title = "Thời điểm"
    @Binding var selection: Date
    var earliest: Date = .distantPast
    @State private var showingPicker = false
    @State private var draft = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "clock").font(CareFont.headline)
                Spacer()
                Button("Bây giờ", systemImage: "arrow.clockwise") { selection = Date() }
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
            }.buttonStyle(.plain).accessibilityLabel("Chọn " + title.lowercased())
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                Form {
                    DatePicker(title, selection: $draft, in: min(earliest, Date.now)...Date.now, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    DatePicker("Giờ", selection: $draft, in: min(earliest, Date.now)...Date.now, displayedComponents: .hourAndMinute)
                }.careScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { showingPicker = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Áp dụng") { selection = draft; showingPicker = false }
                        }
                    }
            }.presentationDetents([.large])
        }
    }
}
