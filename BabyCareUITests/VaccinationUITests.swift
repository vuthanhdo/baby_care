import XCTest

final class VaccinationUITests: XCTestCase {
    @MainActor func testCreateEditAndDeleteVaccination() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-care.language", "vi"]
        app.launch()
        let profile = app.buttons["Hồ sơ Bé An"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10)); profile.tap()
        let history = app.buttons["vaccinationHistoryLink"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        app.reveal(history); history.tap()
        app.buttons["addVaccinationButton"].tap()
        let name = app.textFields["vaccineNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveVaccinationButton"].isEnabled)
        name.tap(); name.typeText("Test vaccine")
        app.buttons["saveVaccinationButton"].tap()
        let record = app.buttons.containing(.staticText, identifier: "Test vaccine").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Vaccination history"; shot.lifetime = .keepAlways; add(shot)
        record.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText(" updated")
        app.buttons["saveVaccinationButton"].tap()
        let edited = app.buttons.containing(.staticText, identifier: "Test vaccine updated").firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
        edited.swipeLeft()
        app.buttons["Xóa"].firstMatch.tap()
        app.alerts.buttons["Xóa"].tap()
        XCTAssertTrue(app.staticTexts["Chưa có lịch sử tiêm chủng"].waitForExistence(timeout: 5))
    }
}
