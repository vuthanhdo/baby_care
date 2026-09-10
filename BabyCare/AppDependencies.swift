import Foundation

/// Composition root: replace this provider with an API-backed CareDataProvider to use cloud storage.
@MainActor enum AppDependencies {
    static func makeViewModel() -> BabyCareViewModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return .preview() }
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
}
