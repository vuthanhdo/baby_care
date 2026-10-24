import XCTest

final class StitchAppearanceTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testRootTabsAndAllActivityGroups() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.quick"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable, "Native tabs must not duplicate Stitch navigation")
        capture(app, "Stitch — Ghi nhanh đầu màn")
        app.swipeUp()
        capture(app, "Stitch — Ghi nhanh danh mục")
        app.buttons["tab.diary"].tap()
        capture(app, "Stitch — Nhật ký")
        app.buttons["tab.statistics"].tap()
        capture(app, "Stitch — Thống kê")
        app.buttons["tab.quick"].tap()
        let medical = app.buttons["medicalGroupButton"]
        app.reveal(medical)
        medical.tap()
        XCTAssertTrue(app.buttons["picker.group.medical"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chọn Y tế")
        app.buttons["picker.group.feeding"].tap()
        capture(app, "Stitch — Chọn Ăn uống")
        app.buttons["picker.group.routine"].tap()
        capture(app, "Stitch — Chọn Sinh hoạt")
    }

    @MainActor
    func testEmailLoginAndSignUpLayouts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-auth"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let email = app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        XCTAssertTrue(app.buttons["auth.apple"].exists || app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Apple'")).firstMatch.exists, "Sign in with Apple missing next to Google")
        capture(app, "Stitch — Đăng nhập")
        email.tap()
        email.typeText("parent@example.com")
        let password = app.secureTextFields["auth.password"]
        password.tap()
        password.typeText("PreviewOnly")
        XCTAssertTrue(app.buttons["auth.submit"].isEnabled)
        app.buttons["Hiện mật khẩu"].tap()
        XCTAssertTrue(app.textFields["auth.password"].exists)
        app.buttons["Ẩn mật khẩu"].tap()
        XCTAssertTrue(app.secureTextFields["auth.password"].exists)
        // Changing screen clears the password and never sends a signup request.
        app.swipeUp()
        app.buttons["auth.toggle"].tap()
        XCTAssertTrue(app.staticTexts["Tạo tài khoản"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["auth.confirmPassword"].exists)
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        capture(app, "Stitch — Đăng ký")
    }

    @MainActor
    func testInlineSignupValidation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-auth"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let email = app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap(); email.typeText("invalid-email")
        XCTAssertTrue(app.staticTexts["auth.emailError"].exists)
        app.swipeUp()
        app.buttons["auth.toggle"].tap()
        let password = app.secureTextFields["auth.password"]
        password.tap(); password.typeText("abcdefgh")
        XCTAssertTrue(app.staticTexts["auth.passwordError"].exists)
        password.typeText("A!")
        XCTAssertFalse(app.staticTexts["auth.passwordError"].exists)
        app.swipeUp()
        let confirmation = app.secureTextFields["auth.confirmPassword"]
        confirmation.tap(); confirmation.typeText("different")
        XCTAssertTrue(app.staticTexts["auth.passwordMismatch"].exists)
    }

    @MainActor
    func testSignupEmailLinkInstructions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-auth", "-care.auth.pendingSignupEmail", "signup@example.com"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        XCTAssertTrue(app.staticTexts["auth.checkEmail"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["auth.otp"].exists)
        XCTAssertFalse(app.buttons["auth.verifyOTP"].exists)
        XCTAssertTrue(app.buttons["Gửi lại email xác thực"].exists)
        app.swipeUp()
        app.buttons["Đã xác minh? Đăng nhập"].tap()
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testProfileMeasurementAndSettingsNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let profile = app.buttons["Hồ sơ Bé An"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        XCTAssertTrue(app.buttons["editBabyProfileButton"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Hồ sơ bé")
        app.buttons["Thêm số đo mới"].tap()
        XCTAssertTrue(app.textFields["weightField"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveMeasurementButton"].isEnabled)
        capture(app, "Stitch — Nhập số đo")
        app.buttons["Hủy"].firstMatch.tap()
        app.buttons["Cài đặt"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Trải nghiệm & Hiển thị"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "Stitch — Cài đặt")
    }

    @MainActor
    func testMedicalDetailAndTemperatureLayouts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.diary"].waitForExistence(timeout: 10))
        app.buttons["tab.diary"].tap()
        let entry = app.buttons.containing(.staticText, identifier: "Nhiệt độ").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.staticTexts["NHIỆT ĐỘ CƠ THỂ"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chi tiết hoạt động")
        app.buttons["Sửa hoạt động"].tap()
        XCTAssertTrue(app.textFields["temperatureField"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Form nhiệt độ")
        // The site, thermometer and reference rows push the time field below the save button.
        let timeField = app.buttons["Chọn thời điểm đo"]
        app.reveal(timeField)
        timeField.tap()
        XCTAssertTrue(app.buttons["Áp dụng"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chọn ngày giờ")
        app.buttons["Hủy"].firstMatch.tap()
        XCTAssertTrue(app.textFields["temperatureField"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIllnessAndReportNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let tracking = app.buttons["Theo dõi và lịch nhắc"]
        XCTAssertTrue(tracking.waitForExistence(timeout: 10))
        tracking.tap()
        XCTAssertTrue(app.staticTexts["Lịch nhắc thuốc của bé"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Theo dõi ốm")
        let report = app.buttons["Xuất báo cáo 48 giờ (PDF / QR)"]
        app.reveal(report)
        XCTAssertTrue(report.isHittable)
        report.tap()
        XCTAssertTrue(app.staticTexts["Chọn nội dung chia sẻ"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chia sẻ báo cáo")
        let preview = app.buttons["Xem trước báo cáo"]
        app.reveal(preview)
        preview.tap()
        let open = app.buttons["Mở bản xem trước"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.staticTexts["BẢN XEM TRƯỚC"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Xem trước báo cáo")
    }

    @MainActor
    func testActivityPickerAndVoiceLayout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launchArguments += ["-care.language", "vi"]
        app.launch()
        let group = app.buttons["medicalGroupButton"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        app.reveal(group)
        group.tap()
        XCTAssertTrue(app.staticTexts["Ghi hoạt động cho Bé An"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chọn hoạt động")
        let voice = app.buttons.containing(.staticText, identifier: "Nói để ghi").firstMatch
        app.reveal(voice)
        voice.tap()
        XCTAssertTrue(app.staticTexts["NỘI DUNG CẦN GHI"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Giọng nói")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
