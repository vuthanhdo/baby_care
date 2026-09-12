import SwiftUI

/// Compact entry forms from the Stitch login, signup and baby setup screens.
struct EntryFormCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 20) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(CareTheme.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(CareTheme.border.opacity(0.7)))
            .shadow(color: CareTheme.accent.opacity(0.05), radius: 10, y: 4)
    }
}

struct EntryFieldLabel: View {
    let title: String
    let icon: String
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        HStack(spacing: 6) {
            CareIcon(name: "Stitch_" + icon, color: CareTheme.accent, size: 18)
            Text(title).font(CareFont.footnote.weight(.semibold))
        }
    }
}

struct EntryInputStyle: TextFieldStyle {
    var shaded = false
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.font(CareFont.subheadline).padding(.horizontal, 14).padding(.vertical, 13)
            .frame(minHeight: 48)
            .background(shaded ? CareTheme.background : CareTheme.surface, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
    }
}
