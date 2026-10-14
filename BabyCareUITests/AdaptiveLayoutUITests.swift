import XCTest

/// iPhone Duo readiness: the same flows must work in compact width (folded), regular width (open,
/// iPad-like) and compact height (folded, landscape). Run this against an iPhone and an iPad destination;
/// the inner display ignores supported orientations, so layouts may only depend on size classes.
final class AdaptiveLayoutUITests: XCTestCase {
    @MainActor
    func testTabsPickerAndFormInPortraitAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-ui-testing", "-care.language", "vi"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let pose = orientation == .portrait ? "portrait" : "landscape"

            for tab in ["tab.quick", "tab.diary", "tab.statistics"] {
                let button = app.buttons[tab]
                XCTAssertTrue(button.waitForExistence(timeout: 5), "\(tab) missing in \(pose)")
                XCTAssertTrue(button.isHittable, "\(tab) hidden in \(pose)")
                button.tap()
                capture(app, "\(pose) – \(tab)")
            }

            app.buttons["tab.quick"].tap()
            let medical = app.buttons["medicalGroupButton"]
            XCTAssertTrue(medical.waitForExistence(timeout: 5))
            for _ in 0..<8 where !medical.isHittable { app.swipeUp() }
            XCTAssertTrue(medical.isHittable, "category card unreachable in \(pose)")
            medical.tap()

            let temperature = app.buttons["picker.kind.temperature"]
            XCTAssertTrue(temperature.waitForExistence(timeout: 5), "activity picker missing in \(pose)")
            capture(app, "\(pose) – picker")
            temperature.tap()

            let field = app.textFields["temperatureField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5), "temperature form missing in \(pose)")
            sleep(1) // Let the push inside the sheet settle.
            for _ in 0..<4 where !field.isHittable { app.swipeUp() }
            XCTAssertTrue(field.isHittable, "temperature field hidden in \(pose)")
            let save = app.buttons["saveActivityButton"]
            if orientation != .portrait && UIDevice.current.userInterfaceIdiom == .pad {
                // Regular width keeps the form in a centered sheet; XCUITest cannot type there reliably in
                // landscape with a hardware keyboard, and no keyboard can cover the field. Check the gate only.
                XCTAssertTrue(save.waitForExistence(timeout: 5))
                XCTAssertFalse(save.isEnabled)
                capture(app, "\(pose) – temperature form")
                app.buttons["Hủy"].firstMatch.tap()
                let close = app.buttons["Đóng"].firstMatch
                if close.waitForExistence(timeout: 3) { close.tap() }
                continue
            }
            field.tap()
            field.typeText("37,5")
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            for _ in 0..<4 where !save.isHittable { app.swipeUp() }
            capture(app, "\(pose) – temperature form")
            XCTAssertTrue(save.isHittable, "save button unreachable with keyboard in \(pose)")
            XCTAssertTrue(save.isEnabled)
            save.tap()
            XCTAssertTrue(app.staticTexts["Đã lưu nhiệt độ"].waitForExistence(timeout: 3), "toast missing in \(pose)")

            // The form pops back to the picker sheet; leave it so the next pose starts from the tabs.
            let close = app.buttons["Đóng"].firstMatch
            if close.waitForExistence(timeout: 3) { close.tap() }
            XCTAssertTrue(app.buttons["tab.diary"].waitForExistence(timeout: 5))
        }
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
