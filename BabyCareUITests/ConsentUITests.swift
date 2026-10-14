import XCTest

final class ConsentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testDocumentsDoNotAcceptAndAllThreeRequiredBeforeProfile() {
        let app = launch()
        let submit = app.buttons["onboardingConsentButton"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertFalse(app.textFields["babyNameField"].exists)
        for document in ["terms", "privacy"] {
            let row = app.buttons["consent.document." + document]
            reveal(row, in: app); row.tap()
            let close = app.buttons["Đóng"]
            XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
            XCTAssertFalse(submit.isEnabled)
        }
        let first = app.buttons["consent.terms"]
        reveal(first, in: app)
        // Inline document link must not toggle the adjacent checkbox either.
        let link = app.links["Điều khoản sử dụng"].firstMatch
        if link.exists {
            link.tap(); app.buttons["Đóng"].tap()
            XCTAssertEqual(first.value as? String, "Chưa chọn")
        }
        selectAll(in: app)
        submit.tap()
        XCTAssertTrue(app.textFields["babyNameField"].waitForExistence(timeout: 10))
        XCTAssertFalse(submit.exists)
    }

    @MainActor func testAcceptanceProceedsWhenServerRejectsOnce() {
        let app = launch(failOnce: true)
        XCTAssertTrue(app.buttons["onboardingConsentButton"].waitForExistence(timeout: 10))
        selectAll(in: app)
        app.buttons["onboardingConsentButton"].tap()
        XCTAssertTrue(app.textFields["babyNameField"].waitForExistence(timeout: 10))
    }

    /// The consent RPC is unreachable or not deployed: three ticks still unlock the gate.
    @MainActor func testStatusFailureStillUnlocksWithThreeTicks() {
        let app = launch(statusFails: true)
        XCTAssertTrue(app.buttons["onboardingConsentButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["consent.error"].exists)
        selectAll(in: app)
        app.buttons["onboardingConsentButton"].tap()
        XCTAssertTrue(app.textFields["babyNameField"].waitForExistence(timeout: 10))
    }

    @MainActor private func launch(failOnce: Bool = false, statusFails: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-consent", "-care.language", "vi"]
        if failOnce { app.launchArguments.append("-ui-testing-consent-failure") }
        if statusFails { app.launchArguments.append("-ui-testing-consent-status-failure") }
        app.launch(); return app
    }
    @MainActor private func selectAll(in app: XCUIApplication) {
        let submit = app.buttons["onboardingConsentButton"]
        for id in ["consent.terms", "consent.data", "consent.guardian"] {
            XCTAssertFalse(submit.isEnabled)
            let checkbox = app.buttons[id]
            reveal(checkbox, in: app)
            XCTAssertEqual(checkbox.value as? String, "Chưa chọn")
            checkbox.tap()
        }
        XCTAssertTrue(submit.isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Three explicit confirmations"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            let footerTop = app.buttons["onboardingConsentButton"].frame.minY
            if element.isHittable && element.frame.maxY < footerTop { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable && element.frame.maxY < app.buttons["onboardingConsentButton"].frame.minY)
    }
}
