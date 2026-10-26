import XCTest

/// Settings → Gia đình & chia sẻ over `SharingUITestFixture` (fake sharing transport, no Supabase).
final class FamilySharingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func openSharing() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-sharing", "-care.language", "vi"]
        app.launch()
        let settings = app.buttons["app.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Cài đặt"].waitForExistence(timeout: 5))
        let family = app.buttons["settings.family"]
        app.reveal(family)
        family.tap()
        XCTAssertTrue(app.navigationBars["Gia đình & chia sẻ"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testOwnerSeesMembersAndCreatesAnInvite() {
        let app = openSharing()
        XCTAssertTrue(app.staticTexts["partner@example.invalid"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["me@example.invalid (bạn)"].exists)
        // Both families are listed so the parent can switch.
        XCTAssertTrue(app.buttons["family.switch.00000000-0000-0000-0000-00000000BB10"].exists)
        XCTAssertTrue(app.staticTexts["Gia đình của grandma@example.invalid"].exists)

        let invite = app.buttons["family.invite.caregiver"]
        app.reveal(invite)
        invite.tap()
        let code = app.staticTexts["family.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertEqual(code.label, "ABCD 2345")
        XCTAssertTrue(app.buttons["Gửi lời mời"].exists)
        app.buttons["Xong"].tap()
        // The open invite is listed with a way to cancel it.
        XCTAssertTrue(app.staticTexts["Lời mời cùng chăm sóc"].waitForExistence(timeout: 5))
    }

    @MainActor func testJoiningWithAWrongCodeExplainsWhy() {
        let app = openSharing()
        let join = app.buttons["family.join"]
        app.reveal(join)
        join.tap()
        let field = app.textFields["family.joinCode"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let confirm = app.buttons["family.joinConfirm"]
        XCTAssertFalse(confirm.isEnabled)
        field.typeText("wxyz-6789")
        // Under load the button can enable a moment after the last keystroke.
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: confirm)
        waitForExpectations(timeout: 5)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Mã mời không đúng. Kiểm tra lại 8 ký tự."].waitForExistence(timeout: 5))
    }
}
