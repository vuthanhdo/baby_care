import XCTest

extension XCUIApplication {
    /// The app window in interface coordinates. On the open iPhone Duo `frame` keeps the inner panel's native
    /// 669 × 951 pt even though the window is 951 × 669, so layout checks and drags use the window instead.
    @MainActor var windowFrame: CGRect {
        let window = windows.firstMatch
        return window.exists ? window.frame : frame
    }

    /// `isHittable` is true for an element whose frame is inside the window even when the bottom tab bar covers it,
    /// so scroll in measured steps until the element's centre sits inside the visible content area.
    /// Each drag ends with a hold, so there is no momentum and the next tap cannot land mid-scroll.
    @MainActor func reveal(_ element: XCUIElement, topInset: CGFloat = 100, bottomInset: CGFloat = 130, attempts: Int = 12) {
        let window = windowFrame
        let low = window.minY + topInset, high = window.maxY - bottomInset
        for _ in 0..<attempts {
            let exists = element.exists
            let center = exists ? element.frame.midY : window.maxY + 1 // lazily built content sits below
            if exists, center >= low, center <= high, element.isHittable { return }
            let step = exists ? min(abs(center - (low + high) / 2), window.height * 0.6) : window.height * 0.5
            // Start in the left gutter: the centre may be a chart or card whose own gesture would eat a slow drag.
            // On wide windows (open iPhone Duo, iPad landscape) the gutter sits right of the leading tab rail.
            // In iPhone landscape the window edge is the Dynamic Island's safe-area inset, outside the scroll
            // view, so the drag starts just left of the element's column instead.
            // A snapshot instead of `frame`: during a push the tabs can vanish between `exists` and the read,
            // and a failed `frame` read fails the test.
            let rail = buttons["tab.quick"]
            let railFrame = rail.exists ? (try? rail.snapshot())?.frame : nil
            let hasRail = railFrame.map { $0.midY < window.midY } ?? false // bottom tabs sit in the lower half
            let column = exists ? (element.frame.minX - 10 - window.minX) / max(window.width, 1) : 0
            let gutter = hasRail ? ((railFrame?.maxX ?? 0) + 10) / max(window.width, 1) : max(0.04, min(column, 0.3))
            let anchor = windows.firstMatch.exists ? windows.firstMatch : self // same space as `windowFrame`
            let start = anchor.coordinate(withNormalizedOffset: CGVector(dx: gutter, dy: 0.55))
            let end = start.withOffset(CGVector(dx: 0, dy: center > high ? -step : step))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.25)
        }
    }
}
