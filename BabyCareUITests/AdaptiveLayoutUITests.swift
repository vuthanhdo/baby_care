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
            // iPadOS resizes the window after the orientation change; taps sent meanwhile are dropped.
            waitForRotation(app, landscape: orientation != .portrait)

            let padLandscape = orientation != .portrait && UIDevice.current.userInterfaceIdiom == .pad
            for tab in ["tab.quick", "tab.diary", "tab.statistics", "tab.feedback"] {
                let button = app.buttons[tab]
                XCTAssertTrue(button.waitForExistence(timeout: 5), "\(tab) missing in \(pose)")
                XCTAssertTrue(button.isHittable, "\(tab) hidden in \(pose)")
                // iPadOS 26 on the simulator reopens the app in a resized window after rotating and drops synthesized
                // taps there; regular width is already exercised in portrait, compact height on iPhone.
                if padLandscape { capture(app, "\(pose) – \(tab)"); continue }
                select(button)
                XCTAssertTrue(button.isSelected, "\(tab) not selected in \(pose)")
                capture(app, "\(pose) – \(tab)")
            }
            if padLandscape { continue }

            select(app.buttons["tab.quick"])
            let medical = app.buttons["medicalGroupButton"]
            XCTAssertTrue(medical.waitForExistence(timeout: 5))
            app.reveal(medical)
            XCTAssertTrue(medical.isHittable, "category card unreachable in \(pose)")
            capture(app, "\(pose) – categories")
            medical.tap()

            let temperature = app.buttons["picker.kind.temperature"]
            if !temperature.waitForExistence(timeout: 5) { app.reveal(medical); medical.tap() }
            XCTAssertTrue(temperature.waitForExistence(timeout: 5), "activity picker missing in \(pose)")
            capture(app, "\(pose) – picker")
            temperature.tap()

            let field = app.textFields["temperatureField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5), "temperature form missing in \(pose)")
            sleep(1) // Let the push inside the sheet settle.
            for _ in 0..<4 where !field.isHittable { app.swipeUp() }
            XCTAssertTrue(field.isHittable, "temperature field hidden in \(pose)")
            let save = app.buttons["saveActivityButton"]
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

    /// Open iPhone Duo and wide iPad windows: tabs move to a leading rail, the quick log splits at the hinge
    /// (the window centre on the Duo) and the diary opens an entry beside the list instead of pushing it.
    @MainActor
    func testWideWindowUsesRailColumnsAndDiaryDetailPane() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-ui-testing", "-care.language", "vi"]
        app.launch()
        // Later tests on the same simulator expect portrait; trying orientations must not leak into them.
        defer { XCUIDevice.shared.orientation = .portrait }
        let quick = app.buttons["tab.quick"], diary = app.buttons["tab.diary"]
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        // Phones in landscape are wide but short and compact width; they keep the bottom tab bar.
        guard makeWindowWide(app) else {
            let window = app.windowFrame
            throw XCTSkip("Window is \(Int(window.width)) × \(Int(window.height)) pt; the open-Duo layout needs a regular-size window.")
        }

        // The open iPhone Duo folds down the middle of its 951-pt display; iPads are wider and have no hinge.
        let window = app.windowFrame
        let foldX = window.midX, hasHinge = window.width < 1000
        XCTAssertLessThan(quick.frame.maxX, 120, "tabs should sit in a leading rail")
        XCTAssertGreaterThan(diary.frame.minY, quick.frame.minY, "rail tabs stack vertically")
        let medical = app.buttons["medicalGroupButton"]
        XCTAssertTrue(medical.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(medical.frame.minX, foldX, "the logging column should sit in the second column")
        if hasHinge { XCTAssertGreaterThanOrEqual(medical.frame.minX, foldX + 15, "no card may cross the hinge") }
        capture(app, "wide – quick log")

        select(diary)
        XCTAssertTrue(diary.isSelected)
        let entry = app.buttons.containing(.staticText, identifier: "Nhiệt độ").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let detail = app.staticTexts["NHIỆT ĐỘ CƠ THỂ"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "selected entry should open in the detail pane")
        XCTAssertLessThan(entry.frame.maxX, detail.frame.minX, "list and detail should sit side by side")
        if hasHinge {
            XCTAssertLessThanOrEqual(entry.frame.maxX, foldX - 15, "the list must end before the hinge")
            XCTAssertGreaterThanOrEqual(detail.frame.minX, foldX + 15, "the detail must start after the hinge")
        }
        XCTAssertTrue(diary.isHittable, "opening an entry must not push over the tabs")
        capture(app, "wide – diary detail")

        select(app.buttons["tab.statistics"])
        XCTAssertTrue(app.buttons["statistics.mode.growth"].waitForExistence(timeout: 5))
        capture(app, "wide – statistics")
    }

    /// Tries the orientations until the window is at least 860 × 600 pt. The open iPhone Duo's inner display is wide
    /// in the device's portrait orientation; iPads are wide in portrait (13") or landscape (mini).
    @MainActor private func makeWindowWide(_ app: XCUIApplication) -> Bool {
        func isWide() -> Bool { app.windowFrame.width >= 860 && app.windowFrame.height >= 600 }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] where !isWide() {
            XCUIDevice.shared.orientation = orientation
            for _ in 0..<12 where !isWide() { usleep(250_000) }
            sleep(1) // let the resize animation finish before tapping
        }
        return isWide()
    }

    /// Polls until the window has the expected aspect, then lets the resize animation finish.
    @MainActor private func waitForRotation(_ app: XCUIApplication, landscape: Bool) {
        for _ in 0..<20 where (app.frame.width > app.frame.height) != landscape { usleep(250_000) }
        sleep(1)
    }

    /// Taps a tab and waits for it to report selection; one retry covers a tap lost to a transition.
    @MainActor private func select(_ tab: XCUIElement) {
        for _ in 0..<2 where !tab.isSelected {
            tab.tap()
            _ = tab.wait(for: \.isSelected, toEqual: true, timeout: 3)
        }
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
