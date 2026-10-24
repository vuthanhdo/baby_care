import Foundation

/// Debug-only sample data that never touches the user's database. `-demo` loads the small fixture the UI tests
/// rely on; `-demo-full`, or a build with the `DEMO` compilation condition (device test builds:
/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEMO'`), loads `CarePreviewData.showcase` so every screen has data.
@MainActor enum CareDemoMode {
    static var isFullBuild: Bool {
        #if DEMO
        true
        #else
        false
        #endif
    }
    static var dataset: (() -> CareDatabase)? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo-full") { return { CarePreviewData.showcase() } }
        if arguments.contains("-demo") { return CarePreviewData.make }
        if isFullBuild { return { CarePreviewData.showcase() } }
        #endif
        return nil
    }
    static var isActive: Bool { dataset != nil }
    /// Store screenshots show the badge a real cloud user sees instead of "Dữ liệu mẫu".
    static var hidesDemoBadge: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-store-screenshots")
        #else
        false
        #endif
    }
}

/// Composition root: replace this provider with an API-backed CareDataProvider to use cloud storage.
@MainActor enum AppDependencies {
    static func makeViewModel() -> BabyCareViewModel {
        #if DEBUG
        if let dataset = CareDemoMode.dataset {
            let data = dataset()
            // The device demo build keeps real local notifications so reminders can be tried end to end.
            let notifications: (any CareReminderService)? = CareDemoMode.isFullBuild ? LocalCareReminderService(scope: "demo") : nil
            return BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), notifications: notifications, initialData: data, isDemo: true)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return BabyCareViewModel(provider: InMemoryCareDataProvider())
        }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-ui-testing-store"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString: arguments[index + 1]) {
            let url = URL.applicationSupportDirectory.appending(path: "BabyCare-UITests/\(id.uuidString)/BabyCare.store")
            return BabyCareViewModel(provider: SwiftDataCareDataProvider(configuration: CarePersistenceConfiguration(storeURL: url)))
        }
        #endif
        return BabyCareViewModel(provider: SwiftDataCareDataProvider(), notifications: LocalCareReminderService())
    }

    /// Home-screen weather. UI tests (`-demo`, `-ui-testing…`) get none so the layout they check stays put;
    /// `-demo-full` shows sample weather for screenshots without asking for location.
    static func makeWeather() -> WeatherViewModel? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // `-live-weather` keeps the real WeatherKit source in demo runs, to debug it on a signed simulator build.
        if arguments.contains("-demo-full") && !arguments.contains("-live-weather") { return WeatherViewModel(sample: WeatherViewModel.sampleWeather) }
        if arguments.contains(where: { ["-demo", "-ui-testing", "-ui-testing-store", "-ui-testing-auth"].contains($0) }) { return nil }
        #endif
        return WeatherViewModel(source: AppleWeatherSource(), location: SystemLocationSource())
    }
}
