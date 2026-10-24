import Foundation

/// A line about caring for a baby, shown under the logo while the app starts. Folk sayings carry their
/// source; the rest are the app's own words.
nonisolated struct CareQuote: Equatable, Sendable {
    /// Vietnamese key, shown through `L10n`.
    let text: String
    let source: String?

    init(_ text: String, source: String? = nil) {
        self.text = text
        self.source = source
    }
}

nonisolated enum CareQuotes {
    static let all = [
        CareQuote("Công cha như núi Thái Sơn, nghĩa mẹ như nước trong nguồn chảy ra.", source: "Ca dao"),
        CareQuote("Có nuôi con mới biết lòng cha mẹ.", source: "Tục ngữ"),
        CareQuote("Con hơn cha là nhà có phúc.", source: "Tục ngữ"),
        CareQuote("Mỗi ngày bé lớn thêm một chút, bố mẹ cũng vậy."),
        CareQuote("Không có bố mẹ hoàn hảo, chỉ có bố mẹ luôn cố gắng vì con."),
        CareQuote("Một giấc ngủ ngon của bé là món quà cho cả nhà."),
        CareQuote("Hãy chăm sóc cả bản thân, vì bé cần bố mẹ khỏe mạnh."),
        CareQuote("Những đêm thức trắng rồi sẽ qua, nụ cười của con thì ở lại."),
        CareQuote("Bình tĩnh là điều đầu tiên con cần khi con ốm."),
        CareQuote("Ghi lại hôm nay để ngày mai yên tâm hơn."),
        CareQuote("Mỗi bé có nhịp lớn riêng, đừng so con với ai."),
        CareQuote("Hôm nay hãy ôm con lâu hơn một chút."),
        CareQuote("Kiên nhẫn hôm nay là kỷ niệm đẹp ngày mai."),
        CareQuote("Bố mẹ an tâm thì con vui khỏe.")
    ]

    static let lastShownKey = "care.splash.lastQuote"

    /// Chosen once per launch, so the splash keeps the same line while it is shown again during loading.
    @MainActor static let forThisLaunch = pick(defaults: .standard)

    /// A random quote other than the one shown at the previous launch.
    static func pick(defaults: UserDefaults, using random: () -> Int = { Int.random(in: 0..<Int.max) }) -> CareQuote {
        let last = defaults.object(forKey: lastShownKey) as? Int
        let choices = all.indices.filter { $0 != last }
        let index = choices[random() % choices.count]
        defaults.set(index, forKey: lastShownKey)
        return all[index]
    }
}
