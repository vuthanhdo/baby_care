import SwiftUI
import UIKit

// MARK: - Window metrics

/// Window size and the display's reserved regions, in window (SwiftUI `.global`) coordinates.
///
/// iPhone Duo folded is a compact-width phone (466 × 678 pt). Open, it is regular width in both orientations
/// (669 × 951 pt) and reports the hinge as a *division* region: content should sit on either side of it,
/// never across it. iOS 27.1 only exposes these regions through UIKit, so `careAdaptiveRoot()` reads them
/// from a probe view and republishes them to SwiftUI.
nonisolated struct CareWindowMetrics: Equatable, Sendable {
    var size: CGSize = .zero
    /// Strips where the display bends (the Duo hinge). Includes inactive ones so layouts stay stable.
    var divisions: [CGRect] = []
    /// Areas covered by hardware or system UI that the safe area may not describe.
    var occlusions: [CGRect] = []
    /// The hinge is neither closed nor flat (book or tabletop posture).
    var isPartiallyOpen = false
    var isRegularWidth = false

    /// Two-column screens need a regular-width window at least this wide.
    static let columnsMinWidth: CGFloat = 760
    /// From this width the tab bar moves to a leading rail, keeping tabs off the hinge and saving height.
    static let sideTabsMinWidth: CGFloat = 860

    var usesSideTabs: Bool { isRegularWidth && size.width >= Self.sideTabsMinWidth }
    /// Accessibility text sizes stay in one column: two narrow columns would truncate or wrap every row.
    func allowsColumns(typeSize: DynamicTypeSize) -> Bool {
        isRegularWidth && size.width >= Self.columnsMinWidth && !typeSize.isAccessibilitySize
    }

    /// The vertical division whose centre lies inside `frame` horizontally, if any (both in window coordinates).
    func verticalDivision(crossing frame: CGRect) -> CGRect? {
        divisions.first { $0.height >= $0.width && $0.midX > frame.minX && $0.midX < frame.maxX }
    }
}

extension EnvironmentValues {
    @Entry var careWindow = CareWindowMetrics()
}

extension View {
    /// Publishes `CareWindowMetrics` to every descendant. Attach once, at the root of the window.
    func careAdaptiveRoot() -> some View { modifier(CareAdaptiveRoot()) }
}

private struct CareAdaptiveRoot: ViewModifier {
    @State private var metrics = CareWindowMetrics()
    @Environment(\.horizontalSizeClass) private var sizeClass
    func body(content: Content) -> some View {
        var published = metrics
        published.isRegularWidth = sizeClass == .regular
        return content
            .environment(\.careWindow, published)
            .background {
                CareWindowProbe { metrics = $0 }
                    .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            }
    }
}

/// Reads the window size, reserved regions and hinge state on every layout pass and hinge update.
private struct CareWindowProbe: UIViewRepresentable {
    var onChange: (CareWindowMetrics) -> Void
    func makeUIView(context: Context) -> ProbeView { ProbeView(onChange: onChange) }
    func updateUIView(_ view: ProbeView, context: Context) { view.onChange = onChange }

    final class ProbeView: UIView {
        var onChange: (CareWindowMetrics) -> Void
        private var published: CareWindowMetrics?
        private var partiallyOpen = false

        init(onChange: @escaping (CareWindowMetrics) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            if #available(iOS 27.1, *) {
                addInteraction(UIHingeInteraction { [weak self] _, update in
                    self?.partiallyOpen = update.hinge?.status == .partiallyOpen
                    self?.publish()
                })
            }
        }
        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() { super.layoutSubviews(); publish() }
        override func didMoveToWindow() { super.didMoveToWindow(); publish() }

        private func publish() {
            guard let window else { return }
            var metrics = CareWindowMetrics(size: window.bounds.size, isPartiallyOpen: partiallyOpen)
            if #available(iOS 27.1, *) {
                metrics.divisions = reservedRegions(kind: .division, options: .includeInactive).map { convert($0.frame, to: nil) }
                metrics.occlusions = reservedRegions(kind: .occlusion).map { convert($0.frame, to: nil) }
            }
            guard metrics != published else { return }
            published = metrics
            // Layout can run while SwiftUI updates the hosting view; publish on the next turn of the run loop.
            DispatchQueue.main.async { [weak self] in self?.onChange(metrics) }
        }
    }
}

// MARK: - Columns

/// Geometry of one screen: a single centred column, or two columns whose gutter covers the fold. Pure for tests.
nonisolated struct CareColumnsPlan: Equatable {
    var originX: CGFloat
    var leadingWidth: CGFloat
    /// Zero when the content is stacked in one column.
    var trailingWidth: CGFloat
    var gutter: CGFloat
    var isSplit: Bool { trailingWidth > 0 }

    static let padding: CGFloat = 20
    static let singleMaxWidth: CGFloat = 620
    static let splitMaxWidth: CGFloat = 1100
    static let minColumnWidth: CGFloat = 320
    static let gutter: CGFloat = 24
    /// Space kept clear on each side of the crease.
    static let foldClearance: CGFloat = 12

    /// - Parameters:
    ///   - width: width offered to the content.
    ///   - split: whether the window allows two columns; ignored when `width` cannot fit two minimum columns.
    ///   - fold: horizontal extent of a vertical division in the content's coordinates.
    static func make(width: CGFloat, split: Bool, fold: ClosedRange<CGFloat>? = nil) -> CareColumnsPlan {
        let available = max(0, width - 2 * padding)
        guard split, available >= 2 * minColumnWidth + gutter else {
            let single = min(available, singleMaxWidth)
            return CareColumnsPlan(originX: (width - single) / 2, leadingWidth: single, trailingWidth: 0, gutter: 0)
        }
        let content = min(available, splitMaxWidth)
        let origin = (width - content) / 2
        var gutter = Self.gutter
        var leading = (content - gutter) / 2
        if let fold {
            let foldGutter = max(gutter, fold.upperBound - fold.lowerBound + 2 * foldClearance)
            let candidate = (fold.lowerBound + fold.upperBound) / 2 - foldGutter / 2 - origin
            if candidate >= minColumnWidth, content - candidate - foldGutter >= minColumnWidth {
                leading = candidate
                gutter = foldGutter
            }
        }
        return CareColumnsPlan(originX: origin, leadingWidth: leading, trailingWidth: content - leading - gutter, gutter: gutter)
    }

    /// Where a list/detail screen divides into two panes, or nil to keep one pane.
    static func paneSplit(width: CGFloat, split: Bool, fold: ClosedRange<CGFloat>? = nil, minPane: CGFloat = 340) -> CGFloat? {
        guard split, width >= 2 * minPane else { return nil }
        if let fold {
            let middle = (fold.lowerBound + fold.upperBound) / 2
            if middle >= minPane, width - middle >= minPane { return middle }
        }
        return (width / 2).rounded()
    }
}

/// Places its first two subviews side by side (split) or stacked (single) following `CareColumnsPlan`.
struct CareColumnsLayout: Layout {
    var split: Bool
    var fold: ClosedRange<CGFloat>?
    var spacing: CGFloat = 20

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? CareColumnsPlan.singleMaxWidth + 2 * CareColumnsPlan.padding
        let plan = CareColumnsPlan.make(width: width, split: split, fold: fold)
        return CGSize(width: width, height: contentHeight(plan, subviews) + 2 * CareColumnsPlan.padding)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = CareColumnsPlan.make(width: bounds.width, split: split, fold: fold)
        let top = bounds.minY + CareColumnsPlan.padding
        let leadingX = bounds.minX + plan.originX
        if plan.isSplit {
            for (index, subview) in subviews.enumerated() {
                let trailing = index > 0
                subview.place(at: CGPoint(x: trailing ? leadingX + plan.leadingWidth + plan.gutter : leadingX, y: top), anchor: .topLeading,
                              proposal: ProposedViewSize(width: trailing ? plan.trailingWidth : plan.leadingWidth, height: nil))
            }
        } else {
            var y = top
            for subview in subviews {
                let size = subview.sizeThatFits(ProposedViewSize(width: plan.leadingWidth, height: nil))
                subview.place(at: CGPoint(x: leadingX, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: plan.leadingWidth, height: nil))
                if size.height > 0 { y += size.height + spacing }
            }
        }
    }

    private func contentHeight(_ plan: CareColumnsPlan, _ subviews: Subviews) -> CGFloat {
        let heights = subviews.enumerated().map { index, subview in
            subview.sizeThatFits(ProposedViewSize(width: plan.isSplit && index > 0 ? plan.trailingWidth : plan.leadingWidth, height: nil)).height
        }
        if plan.isSplit { return heights.max() ?? 0 }
        let visible = heights.filter { $0 > 0 }
        return visible.reduce(0, +) + spacing * CGFloat(max(0, visible.count - 1))
    }
}

/// Scroll content in one column (phones, folded Duo, large text) or two columns split at the fold (open Duo, iPad).
/// Both columns keep their identity when the layout switches, so folding or unfolding never resets their state.
struct CareColumns<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.careWindow) private var window
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var span: ClosedRange<CGFloat> = 0...0

    var body: some View {
        CareColumnsLayout(split: window.allowsColumns(typeSize: typeSize), fold: window.localFold(in: span), spacing: spacing) {
            VStack(alignment: .leading, spacing: spacing) { leading }
            VStack(alignment: .leading, spacing: spacing) { trailing }
        }
        .careHorizontalSpan($span)
    }
}

extension View {
    /// Reports this view's horizontal extent in window coordinates; vertical scrolling does not trigger it.
    func careHorizontalSpan(_ span: Binding<ClosedRange<CGFloat>>) -> some View {
        onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
            let frame = proxy.frame(in: .global)
            return frame.minX...max(frame.minX, frame.maxX)
        } action: { span.wrappedValue = $0 }
    }
}

nonisolated extension CareWindowMetrics {
    /// The division crossing `span` (window coordinates), expressed relative to the span's start.
    func localFold(in span: ClosedRange<CGFloat>) -> ClosedRange<CGFloat>? {
        let frame = CGRect(x: span.lowerBound, y: 0, width: span.upperBound - span.lowerBound, height: 1)
        guard let fold = verticalDivision(crossing: frame) else { return nil }
        return (fold.minX - span.lowerBound)...(fold.maxX - span.lowerBound)
    }
}
