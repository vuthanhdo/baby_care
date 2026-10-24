import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Light or dark look: follows the device unless the parent picks one in Settings.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let preferenceKey = "care.appearance"
    var id: Self { self }
    var title: String {
        switch self {
        case .system: L10n.text("Theo thiết bị")
        case .light: L10n.text("Sáng")
        case .dark: L10n.text("Tối")
        }
    }

    #if canImport(UIKit)
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Sets every window of the app, sheets included. Going back to `.system` through
    /// `preferredColorScheme(nil)` does not reliably undo an earlier override, so this uses UIKit.
    @MainActor func apply() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = interfaceStyle }
        }
    }
    #endif
}

extension View {
    /// Applies the saved appearance when the root appears and whenever it changes.
    func careAppearance() -> some View { modifier(CareAppearanceModifier()) }
}

private struct CareAppearanceModifier: ViewModifier {
    @AppStorage(AppAppearance.preferenceKey) private var appearance = AppAppearance.system.rawValue
    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onAppear { (AppAppearance(rawValue: appearance) ?? .system).apply() }
            .onChange(of: appearance) { _, value in (AppAppearance(rawValue: value) ?? .system).apply() }
        #else
        content
        #endif
    }
}

struct AppearancePicker: View {
    @AppStorage(AppAppearance.preferenceKey) private var appearance = AppAppearance.system.rawValue
    var body: some View {
        Picker(L10n.text("Giao diện"), selection: $appearance) {
            ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("app.appearance")
    }
}
