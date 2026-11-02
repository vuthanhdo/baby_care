import SwiftUI
import WidgetKit

@main
struct BabyCareWidgetsBundle: WidgetBundle {
    var body: some Widget { QuickLogWidget() }
}

/// `QuickLogIntent` is a `LiveActivityIntent`, so the system performs it in the app, which owns the data and the
/// account session. The extension only needs the type to build its buttons; this is never called.
enum QuickLogPerformer {
    static func perform(_ action: QuickLogAction) async {}
}
