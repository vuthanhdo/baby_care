import XCTest

/// Renders the App Store screenshots from the showcase dataset. Skipped unless the runner receives
/// STORE_SCREENSHOTS=1 (pass TEST_RUNNER_STORE_SCREENSHOTS=1 to xcodebuild); STORE_LANGUAGE selects vi or en.
/// `Tools/store_screenshots.sh` runs it per simulator and exports the attachments into AppStore/screenshots.
/// With STORE_HOST_CAPTURE=1 the host takes each picture instead (`Tools/store_screenshots_duo.sh`): XCUITest
/// returns black images for the open iPhone Duo's inner display, `simctl io screenshot --display` does not.
final class StoreScreenshotsUITests: XCTestCase {
    private var language = "vi"
    private var hostCapture = false

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SCREENSHOTS"] == "1", "set STORE_SCREENSHOTS=1 to render store screenshots")
        language = ProcessInfo.processInfo.environment["STORE_LANGUAGE"] ?? "vi"
        hostCapture = ProcessInfo.processInfo.environment["STORE_HOST_CAPTURE"] == "1"
    }

    @MainActor func testCaptureStoreScreens() throws {
        var app = launch()
        XCTAssertTrue(app.buttons["tab.quick"].waitForExistence(timeout: 10))
        settle(); capture("01-quick-log")

        let tracking = app.buttons["illness.open"].firstMatch
        XCTAssertTrue(tracking.waitForExistence(timeout: 5))
        app.reveal(tracking); tracking.tap()
        XCTAssertTrue(app.buttons["illness.logSymptoms"].waitForExistence(timeout: 5)) // present with or without reminders
        settle(); capture("02-illness")
        scroll(app, by: 0.42); settle(); capture("03-illness-chart")

        app = launch()
        app.buttons["tab.statistics"].tap()
        XCTAssertTrue(app.buttons["statistics.mode.growth"].waitForExistence(timeout: 5))
        settle(); capture("04-statistics")
        app.buttons["statistics.mode.growth"].tap(); settle(); capture("05-growth")
        app.buttons["tab.diary"].tap(); settle()
        // Wide windows (open iPhone Duo, iPad) show an entry beside the list; a temperature entry brings its chart.
        if isWide(app) {
            let temperature = app.buttons.matching(identifier: "diary.entry.temperature").firstMatch
            let entry = temperature.exists ? temperature : app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'diary.entry.'")).firstMatch
            if entry.waitForExistence(timeout: 5) { app.reveal(entry); entry.tap(); settle() }
        }
        capture("06-diary")

        app = launch()
        let profile = app.buttons["app.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
        let vaccinations = app.buttons["vaccinationHistoryLink"]
        XCTAssertTrue(vaccinations.waitForExistence(timeout: 5))
        settle(); capture("07-profile")
        app.reveal(vaccinations); vaccinations.tap()
        XCTAssertTrue(app.buttons["addVaccinationButton"].waitForExistence(timeout: 5))
        settle(); capture("08-vaccinations")

        // Family sharing (1.2): the signed-in sharing fixture lays four members over the showcase babies.
        app = launch(extra: ["-ui-testing-sharing"])
        let settings = app.buttons["app.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        let family = app.buttons["settings.family"]
        app.reveal(family) // on iPhone the account rows start below the fold, outside the accessibility tree
        XCTAssertTrue(family.exists); family.tap()
        let member = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "ba.ngoai@example.com")).firstMatch
        XCTAssertTrue(member.waitForExistence(timeout: 5)) // the row combines email and role into one label
        settle(); capture("09-family")
    }

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The app language drives its own strings; the locale arguments make system-formatted chart axes match.
        app.launchArguments = ["-demo-full", "-store-screenshots", "-care.language", language,
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language == "vi" ? "vi_VN" : "en_US"] + extra
        app.launch()
        return app
    }

    private func settle() { sleep(1) }

    /// The leading tab rail appears on wide windows; bottom tabs sit in the lower half.
    @MainActor private func isWide(_ app: XCUIApplication) -> Bool {
        let tab = app.buttons["tab.quick"]
        return tab.exists && tab.frame.midY < app.windowFrame.midY
    }

    /// Measured drag without momentum, so the next capture lands on a predictable position.
    /// Anchored on the window: on the open iPhone Duo `app.frame` keeps the panel's native orientation.
    @MainActor private func scroll(_ app: XCUIApplication, by fraction: CGFloat) {
        let window = app.windows.firstMatch.exists ? app.windows.firstMatch : app
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = start.withOffset(CGVector(dx: 0, dy: -app.windowFrame.height * fraction))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.3)
    }

    @MainActor private func capture(_ name: String) {
        if hostCapture { requestHostCapture(name); return }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Handshake with the host script through the runner's tmp folder, which the host reaches with
    /// `simctl get_app_container <udid> <runner bundle> data`: write `<name>.ready`, wait for `<name>.done`.
    @MainActor private func requestHostCapture(_ name: String) {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("store-capture")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let done = folder.appendingPathComponent("\(name).done")
        try? FileManager.default.removeItem(at: done)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("\(name).ready").path, contents: Data())
        for _ in 0..<120 where !FileManager.default.fileExists(atPath: done.path) { usleep(250_000) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: done.path), "host did not capture \(name)")
    }
}
