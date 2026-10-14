import XCTest

/// Logging a dose from a reminder immediately asks for the next moment instead of leaving the reminder switched off.
final class MedicationFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testDoseFromReminderOffersNextMoment() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-ui-testing", "-care.language", "vi"]
        app.launch()
        let open = app.buttons["Xem theo dõi"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()

        let add = app.buttons["illness.addReminder"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        for _ in 0..<6 where !add.isHittable { app.swipeUp() }
        add.tap()
        let name = app.textFields["reminder.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Paracetamol")
        let amount = app.textFields["reminder.amount"]
        amount.tap(); amount.typeText("5")
        app.buttons["reminder.save"].tap()
        XCTAssertTrue(app.staticTexts["Đã lưu lịch nhắc"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chưa ghi lần nào"].waitForExistence(timeout: 5))

        let logDose = app.buttons["reminder.logDose"]
        XCTAssertTrue(logDose.waitForExistence(timeout: 5))
        for _ in 0..<6 where !logDose.isHittable { app.swipeUp() }
        logDose.tap()
        let save = app.buttons["saveActivityButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "the form is prefilled from the reminder")
        save.tap()

        let fourHours = app.buttons["nextDose.hours.4"]
        XCTAssertTrue(fourHours.waitForExistence(timeout: 5), "next-dose sheet missing after logging from a reminder")
        fourHours.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Mốc tiếp theo:")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Lần gần nhất:")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "MỐC ĐÃ ĐẶT:")).firstMatch.exists)
    }
}
