import XCTest

final class BabyCareUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testDemoTabScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        // The Stitch tab bar is a custom view, not a UITabBar; its buttons carry identifiers.
        XCTAssertTrue(app.buttons["tab.quick"].waitForExistence(timeout: 10))
        for (identifier, title) in [("tab.quick", "Ghi nhanh"), ("tab.diary", "Nhật ký"), ("tab.statistics", "Thống kê")] {
            let tab = app.buttons[identifier]
            tab.tap()
            XCTAssertTrue(tab.wait(for: \.isSelected, toEqual: true, timeout: 3), "\(title) not selected")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = title
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }
}
