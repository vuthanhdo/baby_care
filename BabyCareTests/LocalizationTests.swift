import Foundation
import Testing
@testable import BabyCare

struct LocalizationTests {
    @Test func initialLanguageUsesPrimaryDeviceLanguage() {
        #expect(AppLanguage.initial(preferredLanguages: ["vi-VN"]) == .vietnamese)
        #expect(AppLanguage.initial(preferredLanguages: ["en-GB"]) == .english)
        #expect(AppLanguage.initial(preferredLanguages: ["ja-JP", "vi-VN"]) == .english)
        #expect(AppLanguage.initial(preferredLanguages: ["fr", "en-US"]) == .english)
        #expect(AppLanguage.initial(preferredLanguages: []) == .english)
    }

    @Test func savedPreferenceTakesPriority() {
        #expect(AppLanguage.resolve(saved: "vi", preferredLanguages: ["en"]) == .vietnamese)
        #expect(AppLanguage.resolve(saved: "en", preferredLanguages: ["vi"]) == .english)
        #expect(AppLanguage.resolve(saved: "invalid", preferredLanguages: ["vi"]) == .vietnamese)
    }

    @Test func translationsAndArguments() {
        #expect(L10n.render("Đăng nhập", language: .english) == "Sign in")
        #expect(L10n.render("Đăng nhập", language: .vietnamese) == "Đăng nhập")
        #expect(L10n.render("Đã tạo hồ sơ bé {0}", arguments: ["An {1}"], language: .english) == "Created An {1}'s profile")
        #expect(L10n.render("Unknown user text", language: .english) == "Unknown user text")
    }

    @Test func bothCatalogsHaveMatchingKeysAndPlaceholders() throws {
        let catalogs = try AppLanguage.allCases.map { language in
            let bundle = try #require(L10n.bundles[language])
            let url = try #require(bundle.url(forResource: "Localizable", withExtension: "strings"))
            return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        #expect(Set(catalogs[0].keys) == Set(catalogs[1].keys))
        let regex = try NSRegularExpression(pattern: #"\{[0-9]+\}"#)
        func placeholders(_ value: String) -> [String] {
            regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap {
                Range($0.range, in: value).map { String(value[$0]) }
            }.sorted()
        }
        for (key, value) in catalogs[0] { #expect(placeholders(key) == placeholders(value)) }
    }
}
