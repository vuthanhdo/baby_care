import SwiftUI

@main
struct BabyCareApp: App {
    init() { AppLanguage.registerInitialPreference() }

    var body: some Scene {
        WindowGroup { AppRootView() }
    }
}
