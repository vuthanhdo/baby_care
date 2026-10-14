import XCTest

extension XCUIApplication {
    /// `isHittable` is true for an element whose frame is inside the window even when the bottom tab bar covers it,
    /// so scroll in measured steps until the element's centre sits inside the visible content area.
    /// Each drag ends with a hold, so there is no momentum and the next tap cannot land mid-scroll.
    @MainActor func reveal(_ element: XCUIElement, topInset: CGFloat = 100, bottomInset: CGFloat = 130, attempts: Int = 12) {
        let window = frame
        let low = window.minY + topInset, high = window.maxY - bottomInset
        for _ in 0..<attempts {
            let exists = element.exists
            let center = exists ? element.frame.midY : window.maxY + 1 // lazily built content sits below
            if exists, center >= low, center <= high, element.isHittable { return }
            let step = exists ? min(abs(center - (low + high) / 2), window.height * 0.6) : window.height * 0.5
            // Start in the left gutter: the centre may be a chart or card whose own gesture would eat a slow drag.
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55))
            let end = start.withOffset(CGVector(dx: 0, dy: center > high ? -step : step))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.25)
        }
    }
}
