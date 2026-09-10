import XCTest

final class StitchAppearanceTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testEmailLoginAndSignUpLayouts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-auth"]
        app.launch()
        let email = app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
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
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        capture(app, "Stitch — Đăng ký")
    }

    @MainActor
    func testProfileMeasurementAndSettingsNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
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
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Nhật ký"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Nhật ký"].tap()
        let entry = app.buttons.containing(.staticText, identifier: "Nhiệt độ").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.staticTexts["NHIỆT ĐỘ CƠ THỂ"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chi tiết hoạt động")
        app.buttons["Sửa hoạt động"].tap()
        XCTAssertTrue(app.textFields["temperatureField"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Form nhiệt độ")
        app.buttons["Chọn thời điểm đo"].tap()
        XCTAssertTrue(app.buttons["Áp dụng"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chọn ngày giờ")
        app.buttons["Hủy"].firstMatch.tap()
        XCTAssertTrue(app.textFields["temperatureField"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIllnessAndReportNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        let tracking = app.buttons["Theo dõi và lịch nhắc"]
        XCTAssertTrue(tracking.waitForExistence(timeout: 10))
        tracking.tap()
        XCTAssertTrue(app.staticTexts["Lịch nhắc thuốc của bé"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Theo dõi ốm")
        let report = app.buttons["Xuất báo cáo 48 giờ (PDF / QR)"]
        for _ in 0..<5 where !report.isHittable { app.swipeUp() }
        XCTAssertTrue(report.isHittable)
        report.tap()
        XCTAssertTrue(app.staticTexts["Chọn nội dung chia sẻ"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chia sẻ báo cáo")
        let preview = app.buttons["Xem trước báo cáo"]
        for _ in 0..<5 where !preview.isHittable { app.swipeUp() }
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
        app.launch()
        let group = app.buttons["medicalGroupButton"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        for _ in 0..<5 where !group.isHittable { app.swipeUp() }
        group.tap()
        XCTAssertTrue(app.staticTexts["Ghi hoạt động cho Bé An"].waitForExistence(timeout: 5))
        capture(app, "Stitch — Chọn hoạt động")
        let voice = app.buttons.containing(.staticText, identifier: "Nói để ghi").firstMatch
        for _ in 0..<5 where !voice.isHittable { app.swipeUp() }
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
