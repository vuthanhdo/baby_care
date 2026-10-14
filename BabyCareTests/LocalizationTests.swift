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

    @Test func countUsesSingularKeyInEnglishOnly() {
        #expect(L10n.count(1, one: "1 cữ", many: "{0} cữ", language: .english) == "1 feed")
        #expect(L10n.count(3, one: "1 cữ", many: "{0} cữ", language: .english) == "3 feeds")
        #expect(L10n.count(0, one: "1 bữa", many: "{0} bữa", language: .english) == "0 meals")
        #expect(L10n.count(1, one: "1 cữ", many: "{0} cữ", language: .vietnamese) == "1 cữ")
        #expect(L10n.count(2, one: "1 cữ", many: "{0} cữ", language: .vietnamese) == "2 cữ")
        #expect(L10n.count("1", one: "1 giờ", many: "{0} giờ", language: .english) == "1 hour")
        #expect(L10n.count("1,5", one: "1 giờ", many: "{0} giờ", language: .english) == "1,5 hours")
    }

    @Test func ageTextUsesSingularFormsAndYears() throws {
        let calendar = Calendar.current
        func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        }
        let birth = try day(2024, 1, 15)
        #expect(BabyProfile.ageText(from: birth, at: try day(2024, 1, 15), language: .english) == "0 days old")
        #expect(BabyProfile.ageText(from: birth, at: try day(2024, 1, 16), language: .english) == "1 day old")
        #expect(BabyProfile.ageText(from: birth, at: try day(2024, 1, 20), language: .vietnamese) == "5 ngày tuổi")
        #expect(BabyProfile.ageText(from: birth, at: try day(2024, 2, 15), language: .english) == "1 month old")
        #expect(BabyProfile.ageText(from: birth, at: try day(2025, 1, 15), language: .english) == "12 months old")
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 1, 15), language: .english) == "2 years")
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 2, 15), language: .english) == "2 years 1 month")
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 4, 15), language: .vietnamese) == "2 tuổi 3 tháng")
        #expect(BabyProfile.ageText(from: try day(2026, 4, 15), at: birth, language: .english) == "0 days old")
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
