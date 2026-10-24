import CoreLocation
import Foundation
import Observation
import OSLog
import WeatherKit

nonisolated enum CareWeatherError: Error, Equatable {
    case locationDenied, locationUnavailable, serviceUnavailable
}

/// Apple Weather's required attribution: its mark and a link to the data sources.
struct CareWeatherAttribution: Equatable {
    var lightMark: URL
    var darkMark: URL
    var legalPage: URL
}

@MainActor protocol CareWeatherSource {
    func weather(at location: CLLocation) async throws -> CareWeather
    func attribution() async throws -> CareWeatherAttribution
}

/// WeatherKit; needs the WeatherKit capability on the App ID and the entitlement in Configuration/BabyCare.entitlements.
struct AppleWeatherSource: CareWeatherSource {
    func weather(at location: CLLocation) async throws -> CareWeather {
        let (current, daily) = try await WeatherService.shared.weather(for: location, including: .current, .daily)
        let today = daily.forecast.first
        return CareWeather(date: current.date,
                           temperature: current.temperature.converted(to: .celsius).value,
                           apparentTemperature: current.apparentTemperature.converted(to: .celsius).value,
                           condition: Self.condition(current.condition), symbolName: current.symbolName,
                           high: today?.highTemperature.converted(to: .celsius).value,
                           low: today?.lowTemperature.converted(to: .celsius).value,
                           uvIndex: current.uvIndex.value, precipitationChance: today?.precipitationChance ?? 0,
                           windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value)
    }
    static func condition(_ condition: WeatherCondition) -> CareWeatherCondition {
        switch condition {
        case .blizzard: .blizzard
        case .blowingDust: .blowingDust
        case .blowingSnow: .blowingSnow
        case .breezy: .breezy
        case .clear: .clear
        case .cloudy: .cloudy
        case .drizzle: .drizzle
        case .flurries: .flurries
        case .foggy: .foggy
        case .freezingDrizzle: .freezingDrizzle
        case .freezingRain: .freezingRain
        case .frigid: .frigid
        case .hail: .hail
        case .haze: .haze
        case .heavyRain: .heavyRain
        case .heavySnow: .heavySnow
        case .hot: .hot
        case .hurricane: .hurricane
        case .isolatedThunderstorms: .isolatedThunderstorms
        case .mostlyClear: .mostlyClear
        case .mostlyCloudy: .mostlyCloudy
        case .partlyCloudy: .partlyCloudy
        case .rain: .rain
        case .scatteredThunderstorms: .scatteredThunderstorms
        case .sleet: .sleet
        case .smoky: .smoky
        case .snow: .snow
        case .strongStorms: .strongStorms
        case .sunFlurries: .sunFlurries
        case .sunShowers: .sunShowers
        case .thunderstorms: .thunderstorms
        case .tropicalStorm: .tropicalStorm
        case .windy: .windy
        case .wintryMix: .wintryMix
        @unknown default: .unknown
        }
    }
    func attribution() async throws -> CareWeatherAttribution {
        let attribution = try await WeatherService.shared.attribution
        return CareWeatherAttribution(lightMark: attribution.combinedMarkLightURL, darkMark: attribution.combinedMarkDarkURL,
                                      legalPage: attribution.legalPageURL)
    }
}

enum CareLocationStatus { case notDetermined, denied, authorized }

@MainActor protocol CareLocationSource {
    var status: CareLocationStatus { get }
    /// Asks for When In Use permission if needed and returns one approximate fix.
    func currentLocation() async throws -> CLLocation
}

final class SystemLocationSource: CareLocationSource {
    private let manager = CLLocationManager()
    var status: CareLocationStatus {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        default: .authorized
        }
    }
    func currentLocation() async throws -> CLLocation {
        // The session shows the permission prompt when needed and keeps updates allowed while it is alive.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location }
                    if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                        throw CareWeatherError.locationDenied
                    }
                }
                throw CareWeatherError.locationUnavailable
            }
            group.addTask {
                try await Task.sleep(for: .seconds(20))
                throw CareWeatherError.locationUnavailable
            }
            defer { group.cancelAll() }
            guard let location = try await group.next() else { throw CareWeatherError.locationUnavailable }
            return location
        }
    }
}

/// Weather for the home screen. Nothing is requested until the parent turns it on, and the location only
/// goes to Apple Weather; it is not stored.
@MainActor @Observable
final class WeatherViewModel {
    enum Phase: Equatable { case needsPermission, denied, loading, loaded(CareWeather), failed }
    private(set) var phase: Phase
    private(set) var attribution: CareWeatherAttribution?
    /// Why the last attempt failed, in words the parent can act on or report.
    private(set) var failure: String?
    /// Sample weather in demo builds.
    let isSample: Bool
    @ObservationIgnored private let source: (any CareWeatherSource)?
    @ObservationIgnored private let location: (any CareLocationSource)?
    @ObservationIgnored private var loadedAt: Date?
    static let refreshInterval: TimeInterval = 30 * 60
    private static let log = Logger(subsystem: "com.vuthanhdo.BabyCare", category: "weather")

    init(source: any CareWeatherSource, location: any CareLocationSource) {
        self.source = source
        self.location = location
        isSample = false
        switch location.status {
        case .authorized: phase = .loading
        case .denied: phase = .denied
        case .notDetermined: phase = .needsPermission
        }
    }

    init(sample: CareWeather) {
        source = nil
        location = nil
        isSample = true
        phase = .loaded(sample)
        loadedAt = .distantFuture
    }

    /// Called when the card appears: reloads stale weather only if permission was already given.
    func refreshIfNeeded(now: Date = Date()) async {
        guard let location, location.status == .authorized else {
            if let location, case .loading = phase { phase = location.status == .denied ? .denied : .needsPermission }
            return
        }
        if let loadedAt, now.timeIntervalSince(loadedAt) < Self.refreshInterval, case .loaded = phase { return }
        await load()
    }

    /// The parent tapped the card: may show the permission prompt.
    func enable() async { await load() }

    private func load() async {
        guard let source, let location else { return }
        if case .loaded = phase {} else { phase = .loading }
        let fix: CLLocation
        do {
            fix = try await location.currentLocation()
        } catch CareWeatherError.locationDenied {
            phase = .denied; return
        } catch {
            Self.log.error("Location failed: \(String(describing: error), privacy: .public)")
            failure = L10n.text("Chưa xác định được vị trí. Kiểm tra Dịch vụ định vị trong Cài đặt rồi thử lại.")
            phase = location.status == .denied ? .denied : .failed
            return
        }
        do {
            let weather = try await source.weather(at: fix)
            phase = .loaded(weather)
            failure = nil
            loadedAt = Date()
            if attribution == nil { attribution = try? await source.attribution() }
        } catch {
            Self.log.error("WeatherKit failed: \(String(describing: error), privacy: .public)")
            failure = Self.describe(error)
            phase = .failed
        }
    }

    /// WeatherKit reports a missing App ID service as an authentication failure of its daemon.
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        let authFailed = (error as? WeatherError) == .permissionDenied || ns.domain.contains("JWTAuthenticator")
        let code = "\(ns.domain) \(ns.code)"
        return authFailed
            ? L10n.text("Apple Weather chưa cấp quyền cho ứng dụng này (WeatherKit). ({0})", code)
            : L10n.text("Không lấy được dữ liệu từ Apple Weather. ({0})", code)
    }

    static var sampleWeather: CareWeather {
        CareWeather(date: Date(), temperature: 31, apparentTemperature: 35, condition: .partlyCloudy,
                    symbolName: "cloud.sun.fill", high: 33, low: 26, uvIndex: 8, precipitationChance: 0.4, windSpeed: 12)
    }
}
