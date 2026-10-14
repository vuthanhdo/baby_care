import SwiftUI

nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case vietnamese = "vi"
    static let preferenceKey = "care.language"
    var id: String { rawValue }
    var title: String { self == .english ? "English" : "Tiếng Việt" }
    var locale: Locale { Locale(identifier: self == .english ? "en_US" : "vi_VN") }

    /// Use the device's primary language, not a lower-priority supported language.
    static func initial(preferredLanguages: [String]) -> Self {
        guard let first = preferredLanguages.first else { return .english }
        return Locale(identifier: first).language.languageCode?.identifier == "vi" ? .vietnamese : .english
    }

    static func resolve(saved: String?, preferredLanguages: [String]) -> Self {
        saved.flatMap(Self.init(rawValue:)) ?? initial(preferredLanguages: preferredLanguages)
    }

    static var current: Self {
        resolve(saved: UserDefaults.standard.string(forKey: preferenceKey), preferredLanguages: Locale.preferredLanguages)
    }

    static func registerInitialPreference() {
        if UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) == nil {
            UserDefaults.standard.set(initial(preferredLanguages: Locale.preferredLanguages).rawValue, forKey: preferenceKey)
        }
    }
}

/// Explicit bundles support instant in-app switching without changing iOS preferences.
nonisolated enum L10n {
    static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"), let bundle = Bundle(path: path) else { return nil }
        return (language, bundle)
    })

    static func text(_ key: String, _ arguments: String...) -> String {
        render(key, arguments: arguments, language: .current)
    }

    /// English needs a singular form; the Vietnamese keys differ only by the number.
    static func count(_ count: Int, one: String, many: String, language: AppLanguage = .current) -> String {
        count == 1 ? render(one, language: language) : render(many, arguments: ["\(count)"], language: language)
    }
    /// For decimals that are already formatted, such as sleep hours.
    static func count(_ formatted: String, one: String, many: String, language: AppLanguage = .current) -> String {
        formatted == "1" ? render(one, language: language) : render(many, arguments: [formatted], language: language)
    }

    static func render(_ key: String, arguments: [String] = [], language: AppLanguage) -> String {
        let format = bundles[language]?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
        // Replace placeholders once; user content containing braces is never reinterpreted.
        guard !arguments.isEmpty, let expression = try? NSRegularExpression(pattern: #"\{([0-9]+)\}"#) else { return format }
        var result = format
        for match in expression.matches(in: format, range: NSRange(format.startIndex..., in: format)).reversed() {
            guard let digits = Range(match.range(at: 1), in: format), let index = Int(format[digits]),
                  arguments.indices.contains(index), let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: arguments[index])
        }
        return result
    }
}

struct LanguagePicker: View {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.current.rawValue
    var body: some View {
        Picker(L10n.text("Ngôn ngữ"), selection: $language) {
            ForEach(AppLanguage.allCases) { Text(verbatim: $0.title).tag($0.rawValue) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("app.language")
    }
}
