import XCTest

final class BabyCareUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testDemoTabScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let tabs = app.tabBars
        XCTAssertTrue(tabs.buttons["Ghi nhanh"].waitForExistence(timeout: 10))
        for title in ["Ghi nhanh", "Nhật ký", "Thống kê"] {
            tabs.buttons[title].tap()
            XCTAssertTrue(tabs.buttons[title].isSelected)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = title
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }
}
