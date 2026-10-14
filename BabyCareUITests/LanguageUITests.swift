import XCTest

final class LanguageUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSignInSwitchPreservesInputAndPersistsAcrossLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-auth"]
        app.launch()
        let picker = app.buttons["app.language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["English"].tap()
        XCTAssertEqual(app.buttons["auth.submit"].label, "Sign in")
        let email = app.textFields["auth.email"]
        email.tap(); email.typeText("parent@example.com")
        app.swipeDown()
        picker.tap()
        app.buttons["Tiếng Việt"].tap()
        XCTAssertEqual(app.buttons["auth.submit"].label, "Đăng nhập")
        XCTAssertEqual(email.value as? String, "parent@example.com")
        picker.tap(); app.buttons["English"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["auth.submit"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["auth.submit"].label, "Sign in")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "English sign-in"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.swipeUp(); app.buttons["auth.toggle"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["auth.confirmPassword"].exists)
        let signup = XCTAttachment(screenshot: app.screenshot())
        signup.name = "English sign-up"; signup.lifetime = .keepAlways; add(signup)
    }

    @MainActor
    func testEnglishProfileAndActivitySave() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-store", UUID().uuidString, "-care.language", "en"]
        app.launch()
        let name = app.textFields["babyNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["babyAvatarPicker"].exists)
        let setup = XCTAttachment(screenshot: app.screenshot())
        setup.name = "English baby setup"; setup.lifetime = .keepAlways; add(setup)
        name.tap(); name.typeText("Alex")
        app.buttons["createBabyButton"].tap()
        let medical = app.buttons["medicalGroupButton"]
        XCTAssertTrue(medical.waitForExistence(timeout: 5))
        medical.tap()
        let temperature = app.buttons.containing(.staticText, identifier: "Temperature").firstMatch
        XCTAssertTrue(temperature.waitForExistence(timeout: 5))
        temperature.tap()
        let value = app.textFields["temperatureField"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        value.tap(); value.typeText("37.5")
        XCTAssertTrue(app.buttons["saveActivityButton"].isEnabled)
        app.buttons["saveActivityButton"].tap()
        XCTAssertTrue(app.staticTexts["Saved temperature"].waitForExistence(timeout: 3))
        let skipEpisode = app.buttons["No, just log the temperature"]
        XCTAssertTrue(skipEpisode.waitForExistence(timeout: 3))
        skipEpisode.tap()
        let diary = app.buttons["tab.diary"]
        if !diary.isHittable { app.buttons["Close"].firstMatch.tap() }
        diary.tap()
        XCTAssertTrue(app.staticTexts["Temperature"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "37.5")).firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["tab.diary"].waitForExistence(timeout: 10))
        app.buttons["tab.diary"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "37.5")).firstMatch.exists)
    }

    @MainActor
    func testSettingsSwitchKeepsScreenAndUpdatesTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        let settings = app.buttons["app.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let picker = app.buttons["app.language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap(); app.buttons["English"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.staticTexts["Text size"].exists)
        picker.tap(); app.buttons["Tiếng Việt"].tap()
        XCTAssertTrue(app.navigationBars["Cài đặt"].exists)
        XCTAssertTrue(app.staticTexts["Cỡ chữ"].exists)
    }
}
