import XCTest

/// The Góp ý tab over the fake transport of `SharingUITestFixture` (no Supabase).
final class FeedbackUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func openFeedback() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-sharing", "-care.language", "vi"]
        app.launch()
        let tab = app.buttons["tab.feedback"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.staticTexts["Góp ý cho Bé Khỏe"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testSuggestionIsSentAndThanked() {
        let app = openFeedback()
        let send = app.buttons["feedback.send"]
        XCTAssertFalse(send.isEnabled) // nothing written yet
        app.segmentedControls["feedback.kind"].buttons["Góp ý"].tap() // the tab carries the same title
        let message = app.textViews["feedback.message"]
        message.tap()
        message.typeText("Thêm nhắc uống nước cho bé")
        // The counter follows the text (its exact number depends on how the keyboard composes the diacritics).
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label ENDSWITH %@ AND NOT label BEGINSWITH %@", "/4000", "0/")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["0/4000"].exists)
        XCTAssertTrue(app.switches["feedback.allowContact"].exists)
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        waitForExpectations(timeout: 5)
        send.tap()
        XCTAssertTrue(app.staticTexts["Cảm ơn bạn!"].waitForExistence(timeout: 5))
        // The tab stays open with a fresh form for the next message.
        app.buttons["feedback.done"].tap()
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0/4000"].exists)
        XCTAssertFalse(send.isEnabled)
    }

    @MainActor func testFailedSendKeepsTheMessageAndRetries() {
        let app = openFeedback()
        let message = app.textViews["feedback.message"]
        message.tap()
        message.typeText("Biểu đồ trống khi lỗi mạng")
        let send = app.buttons["feedback.send"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        waitForExpectations(timeout: 5)
        send.tap()
        // The fake transport fails the first time: the error shows and the text stays for another try.
        let error = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Không kết nối được")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.isHittable) // shown beside the button, not below the fold
        XCTAssertEqual(message.value as? String, "Biểu đồ trống khi lỗi mạng")
        send.tap()
        XCTAssertTrue(app.staticTexts["Cảm ơn bạn!"].waitForExistence(timeout: 5))
    }
}
