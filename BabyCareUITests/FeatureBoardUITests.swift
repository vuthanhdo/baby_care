import XCTest

/// The feature board in the Góp ý tab, over the fake transport of `SharingUITestFixture` (no Supabase).
final class FeatureBoardUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func openBoard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-sharing", "-care.language", "vi"]
        app.launch()
        let tab = app.buttons["tab.feedback"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let mode = app.segmentedControls["feedback.mode"].buttons["Bình chọn tính năng"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        XCTAssertTrue(app.staticTexts["Nhắc bé uống nước"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testVotingCountsOnceAndCanBeTakenBack() {
        let app = openBoard()
        let vote = app.buttons["features.vote.00000000-0000-0000-0000-0000000000E1"]
        XCTAssertTrue(vote.waitForExistence(timeout: 5))
        XCTAssertEqual(vote.value as? String, "12 phiếu")
        vote.tap()
        expectation(for: NSPredicate(format: "value == %@", "13 phiếu"), evaluatedWith: vote)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(vote.label, "Bỏ bình chọn")
        vote.tap()
        expectation(for: NSPredicate(format: "value == %@", "12 phiếu"), evaluatedWith: vote)
        waitForExpectations(timeout: 5)
        // A shipped feature shows its count but takes no more votes.
        let shipped = app.buttons["features.vote.00000000-0000-0000-0000-0000000000E3"]
        XCTAssertEqual(shipped.value as? String, "20 phiếu")
        XCTAssertFalse(shipped.isEnabled)
        XCTAssertTrue(app.staticTexts["Đã có trong app"].exists)
    }

    @MainActor func testNewSuggestionWaitsForReview() {
        let app = openBoard()
        app.buttons["features.suggest"].tap()
        let title = app.textFields["features.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let submit = app.buttons["features.submit"]
        XCTAssertFalse(submit.isEnabled)
        title.typeText("Biểu đồ giấc ngủ theo tuần")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: submit)
        waitForExpectations(timeout: 5)
        submit.tap()
        XCTAssertTrue(app.staticTexts["Biểu đồ giấc ngủ theo tuần"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chờ duyệt"].exists)
        XCTAssertTrue(app.staticTexts["Đề xuất của bạn"].exists)
        // Pulling to refresh clears the thanks; the suggestion stays under review.
        let thanks = app.staticTexts["Cảm ơn bạn! Đề xuất sẽ hiện cho mọi người sau khi được duyệt."]
        XCTAssertTrue(thanks.exists)
        let start = app.buttons["features.suggest"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 400)))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: thanks)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["Chờ duyệt"].exists)
    }

    /// App Review Guideline 1.2: published suggestions can be reported from a long press.
    @MainActor func testPublishedSuggestionCanBeReported() {
        let app = openBoard()
        app.staticTexts["Nhắc bé uống nước"].press(forDuration: 1.2)
        let menuItem = app.buttons["Báo cáo nội dung không phù hợp"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.tap()
        XCTAssertTrue(app.staticTexts["Báo cáo đề xuất này?"].waitForExistence(timeout: 5))
        app.buttons["Báo cáo nội dung không phù hợp"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Đã gửi báo cáo. Cảm ơn bạn."].waitForExistence(timeout: 5))
    }

    @MainActor func testSignedOutBoardAsksToSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-care.language", "vi"]
        app.launch()
        let tab = app.buttons["tab.feedback"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        app.segmentedControls["feedback.mode"].buttons["Bình chọn tính năng"].tap()
        XCTAssertTrue(app.staticTexts["Hãy đăng nhập để bình chọn và đề xuất tính năng."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Chưa có đề xuất nào. Hãy gửi đề xuất đầu tiên!"].exists)
        XCTAssertFalse(app.buttons["features.suggest"].isEnabled)
    }
}
