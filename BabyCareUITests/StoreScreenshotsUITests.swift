import XCTest

/// Renders the App Store screenshots from the showcase dataset. Skipped unless the runner receives
/// STORE_SCREENSHOTS=1 (pass TEST_RUNNER_STORE_SCREENSHOTS=1 to xcodebuild); STORE_LANGUAGE selects vi or en.
/// `Tools/store_screenshots.sh` runs it per simulator and exports the attachments into AppStore/screenshots.
final class StoreScreenshotsUITests: XCTestCase {
    private var language = "vi"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SCREENSHOTS"] == "1", "set STORE_SCREENSHOTS=1 to render store screenshots")
        language = ProcessInfo.processInfo.environment["STORE_LANGUAGE"] ?? "vi"
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
        app.swipeUp(); settle(); capture("03-illness-chart")

        app = launch()
        app.buttons["tab.statistics"].tap()
        XCTAssertTrue(app.buttons["statistics.mode.growth"].waitForExistence(timeout: 5))
        settle(); capture("04-statistics")
        app.buttons["statistics.mode.growth"].tap(); settle(); capture("05-growth")
        app.buttons["tab.diary"].tap(); settle(); capture("06-diary")

        app = launch()
        let profile = app.buttons["app.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5)); profile.tap()
        let vaccinations = app.buttons["vaccinationHistoryLink"]
        XCTAssertTrue(vaccinations.waitForExistence(timeout: 5))
        settle(); capture("07-profile")
        app.reveal(vaccinations); vaccinations.tap()
        XCTAssertTrue(app.buttons["addVaccinationButton"].waitForExistence(timeout: 5))
        settle(); capture("08-vaccinations")
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-full", "-care.language", language]
        app.launch()
        return app
    }

    private func settle() { sleep(1) }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
