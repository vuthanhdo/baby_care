import XCTest

/// The first temperature with no episode open offers to start illness tracking.
final class IllnessOfferUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func logFirstTemperature() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-store", UUID().uuidString, "-care.language", "vi"]
        app.launch()
        let name = app.textFields["babyNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap(); name.typeText("Bé Sốt")
        app.buttons["createBabyButton"].tap()
        let medical = app.buttons["medicalGroupButton"]
        XCTAssertTrue(medical.waitForExistence(timeout: 5))
        medical.tap()
        let choice = app.buttons.containing(.staticText, identifier: "Nhiệt độ").firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        let field = app.textFields["temperatureField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("38,6")
        app.buttons["saveActivityButton"].tap()
        return app
    }

    @MainActor func testStartingTheOfferedEpisodeTracksTheIllness() {
        let app = logFirstTemperature()
        let start = app.buttons["illnessOffer.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        capture(app, "1-offer")
        start.tap()
        // The confirmation toast lasts 4 s and can hide behind the closing sheet; check the lasting result instead.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: start)
        waitForExpectations(timeout: 10)
        capture(app, "2-started")
        // Back on Quick log, the episode card replaces the start link.
        let close = app.buttons["Đóng"].firstMatch
        if close.waitForExistence(timeout: 3) { close.tap() }
        XCTAssertTrue(app.staticTexts["Đang theo dõi ốm"].waitForExistence(timeout: 5))
        capture(app, "3-tracking")
    }

    @MainActor func testDecliningKeepsOnlyTheReading() {
        let app = logFirstTemperature()
        let skip = app.buttons["illnessOffer.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertFalse(skip.waitForExistence(timeout: 2))
        let close = app.buttons["Đóng"].firstMatch
        if close.waitForExistence(timeout: 3) { close.tap() }
        XCTAssertTrue(app.buttons["tab.quick"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Đang theo dõi ốm"].exists)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
