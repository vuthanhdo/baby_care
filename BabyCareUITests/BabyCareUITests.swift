import XCTest

final class BabyCareUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCreateProfileAndRecordTemperatureInDiary() throws {
        let app = XCUIApplication()
        // A unique on-disk SwiftData store for this test, isolated from real app data.
        app.launchArguments = ["-ui-testing-store", UUID().uuidString]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()

        let name = app.textFields["babyNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        capture(app, name: "A – Hồ sơ đầu tiên")
        name.tap()
        name.typeText("Bé Kiểm thử")
        let create = app.buttons["createBabyButton"]
        XCTAssertTrue(create.isEnabled)
        create.tap()

        let medicalGroup = app.buttons["medicalGroupButton"]
        XCTAssertTrue(medicalGroup.waitForExistence(timeout: 5))
        medicalGroup.tap()
        let temperatureChoice = app.buttons.containing(.staticText, identifier: "Nhiệt độ").firstMatch
        XCTAssertTrue(temperatureChoice.waitForExistence(timeout: 5))
        temperatureChoice.tap()
        let temperature = app.textFields["temperatureField"]
        XCTAssertTrue(temperature.waitForExistence(timeout: 5))
        temperature.tap()
        temperature.typeText("37,5")
        let save = app.buttons["saveActivityButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        // The confirmation banner must be visible inside the still-open picker sheet.
        XCTAssertTrue(app.staticTexts["Đã lưu nhiệt độ"].waitForExistence(timeout: 3))
        // First reading without an episode offers to start one; decline here.
        let skipEpisode = app.buttons["illnessOffer.skip"]
        XCTAssertTrue(skipEpisode.waitForExistence(timeout: 3))
        skipEpisode.tap()

        // A pushed form returns to the activity picker; close that sheet if present.
        let diaryTab = app.buttons["tab.diary"]
        if !diaryTab.isHittable {
            let close = app.buttons["Đóng"].firstMatch
            if close.waitForExistence(timeout: 3) { close.tap() }
        }
        XCTAssertTrue(diaryTab.waitForExistence(timeout: 5))
        diaryTab.tap()
        XCTAssertTrue(app.staticTexts["Nhiệt độ"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "37,5")).firstMatch.exists)
        capture(app, name: "D – Nhiệt độ đã lưu trong nhật ký")

        app.terminate()
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.diary"].waitForExistence(timeout: 10))
        app.buttons["tab.diary"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "37,5")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["babyNameField"].exists)
        capture(app, name: "D – Dữ liệu còn sau khi tắt và mở lại app")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
