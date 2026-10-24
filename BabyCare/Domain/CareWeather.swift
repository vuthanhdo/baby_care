import Foundation

/// Today's outdoor weather where the parent is, reduced to what the home card needs.
nonisolated struct CareWeather: Equatable, Sendable {
    var date: Date
    /// °C.
    var temperature: Double
    var apparentTemperature: Double
    var condition: CareWeatherCondition
    var symbolName: String
    var high: Double?
    var low: Double?
    var uvIndex: Int
    /// Chance of rain or snow today, 0...1.
    var precipitationChance: Double
    /// km/h.
    var windSpeed: Double
}

/// WeatherKit's conditions, named in the app's own language: WeatherKit's descriptions follow the device
/// language, which can differ from the language picked in the app.
nonisolated enum CareWeatherCondition: String, CaseIterable, Sendable {
    case clear, mostlyClear, partlyCloudy, mostlyCloudy, cloudy, foggy, haze, smoky, blowingDust, breezy, windy
    case drizzle, rain, heavyRain, sunShowers, isolatedThunderstorms, scatteredThunderstorms, thunderstorms
    case strongStorms, tropicalStorm, hurricane, hot, frigid, hail, freezingDrizzle, freezingRain, sleet
    case snow, heavySnow, flurries, sunFlurries, blowingSnow, blizzard, wintryMix, unknown

    var title: String {
        switch self {
        case .clear: L10n.text("Trời quang")
        case .mostlyClear: L10n.text("Ít mây")
        case .partlyCloudy: L10n.text("Có mây rải rác")
        case .mostlyCloudy: L10n.text("Nhiều mây")
        case .cloudy: L10n.text("Âm u")
        case .foggy: L10n.text("Sương mù")
        case .haze: L10n.text("Mù khô")
        case .smoky: L10n.text("Khói mù")
        case .blowingDust: L10n.text("Gió bụi")
        case .breezy: L10n.text("Gió nhẹ")
        case .windy: L10n.text("Gió mạnh")
        case .drizzle: L10n.text("Mưa phùn")
        case .rain: L10n.text("Mưa")
        case .heavyRain: L10n.text("Mưa to")
        case .sunShowers: L10n.text("Mưa bóng mây")
        case .isolatedThunderstorms: L10n.text("Dông rải rác")
        case .scatteredThunderstorms: L10n.text("Có dông")
        case .thunderstorms: L10n.text("Dông")
        case .strongStorms: L10n.text("Dông mạnh")
        case .tropicalStorm: L10n.text("Bão nhiệt đới")
        case .hurricane: L10n.text("Bão lớn")
        case .hot: L10n.text("Nắng nóng")
        case .frigid: L10n.text("Rét đậm")
        case .hail: L10n.text("Mưa đá")
        case .freezingDrizzle: L10n.text("Mưa phùn băng giá")
        case .freezingRain: L10n.text("Mưa băng giá")
        case .sleet: L10n.text("Mưa tuyết")
        case .snow: L10n.text("Tuyết")
        case .heavySnow: L10n.text("Tuyết dày")
        case .flurries: L10n.text("Tuyết rơi nhẹ")
        case .sunFlurries: L10n.text("Tuyết nhẹ, có nắng")
        case .blowingSnow: L10n.text("Tuyết bay")
        case .blizzard: L10n.text("Bão tuyết")
        case .wintryMix: L10n.text("Mưa lẫn tuyết")
        case .unknown: L10n.text("Thời tiết hiện tại")
        }
    }
}

/// One thing to put on or bring, drawn as a cute emoji with a one- or two-word label.
nonisolated struct OutfitItem: Equatable, Hashable, Sendable {
    let icon: String
    /// Vietnamese key, shown through `L10n`.
    let label: String
}

/// What to dress the baby in for going out, from the feels-like temperature, rain, UV and wind.
/// General guidance only (layering advice follows the AAP); the parent checks the baby's neck and back.
nonisolated enum OutfitAdvice {
    static func items(for weather: CareWeather, ageInMonths: Int) -> [OutfitItem] {
        let feels = weather.apparentTemperature
        var items: [OutfitItem]
        switch feels {
        case 32...: items = [.init(icon: "👕", label: "Áo cộc mỏng"), .init(icon: "🩳", label: "Quần đùi"),
                             .init(icon: "👒", label: "Mũ rộng vành"), .init(icon: "🍼", label: "Uống thêm")]
        case 27..<32: items = [.init(icon: "👕", label: "Áo cotton mỏng"), .init(icon: "👒", label: "Mũ rộng vành")]
        case 22..<27: items = [.init(icon: "👕", label: "Áo cotton mỏng"), .init(icon: "🧥", label: "Áo khoác mỏng")]
        case 17..<22: items = [.init(icon: "👚", label: "Áo dài tay"), .init(icon: "🧦", label: "Tất")]
        case 12..<17: items = [.init(icon: "🧥", label: "Áo khoác ấm"), .init(icon: "🧢", label: "Mũ"), .init(icon: "🧦", label: "Tất")]
        default: items = [.init(icon: "🧥", label: "Áo khoác dày"), .init(icon: "🧣", label: "Khăn"),
                          .init(icon: "🧤", label: "Găng tay"), .init(icon: "🧦", label: "Tất dày")]
        }
        if ageInMonths < 12 && feels < 22 { items.append(.init(icon: "👶", label: "Thêm 1 lớp")) }
        if weather.precipitationChance >= 0.4 { items.append(.init(icon: "☂️", label: "Áo mưa")) }
        if weather.uvIndex >= 6 {
            // Sunscreen is for babies from 6 months; younger ones stay in the shade.
            items.append(ageInMonths < 6 ? .init(icon: "⛱️", label: "Ở chỗ râm") : .init(icon: "🧴", label: "Kem chống nắng"))
        }
        if weather.uvIndex >= 3 && !items.contains(where: { ["👒", "🧢"].contains($0.icon) }) {
            items.append(.init(icon: "🧢", label: "Đội mũ"))
        }
        if weather.windSpeed >= 30 { items.append(.init(icon: "🌬️", label: "Che gió")) }
        return items
    }
}
