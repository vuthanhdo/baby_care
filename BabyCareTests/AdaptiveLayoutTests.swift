import CoreGraphics
import SwiftUI
import Testing
@testable import BabyCare

/// iPhone Duo: one column folded, two columns split at the hinge when open. Numbers come from the iOS 27.1
/// simulator: the open display is 951 × 669 pt, the hinge a 40-pt division at x 455.5, the status cluster
/// reserves 84 pt on the right and the tab rail takes 84 pt on the left.
struct AdaptiveLayoutTests {
    private let openDuo = CareWindowMetrics(size: CGSize(width: 951, height: 669),
                                            divisions: [CGRect(x: 455.5, y: 0, width: 40, height: 669)], isRegularWidth: true)

    @Test func phonesAndTheOpenDuoInPortraitKeepOneCentredColumn() {
        let phone = CareColumnsPlan.make(width: 402, split: false)
        #expect(!phone.isSplit)
        #expect(phone.leadingWidth == 362 && phone.originX == 20)
        // 669 pt cannot hold two 320-pt columns, even though the window is regular width.
        let portrait = CareColumnsPlan.make(width: 669, split: true)
        #expect(!portrait.isSplit)
        #expect(portrait.leadingWidth == CareColumnsPlan.singleMaxWidth)
    }

    @Test func openDuoColumnsLeaveTheHingeClear() throws {
        let fold = try #require(openDuo.localFold(in: 84...867))
        #expect(fold == 371.5...411.5)
        let plan = CareColumnsPlan.make(width: 783, split: true, fold: fold)
        #expect(plan.isSplit)
        #expect(plan.originX + plan.leadingWidth <= fold.lowerBound)
        #expect(plan.originX + plan.leadingWidth + plan.gutter >= fold.upperBound)
        #expect(plan.leadingWidth >= CareColumnsPlan.minColumnWidth)
        #expect(plan.trailingWidth >= CareColumnsPlan.minColumnWidth)
        #expect(plan.originX + plan.leadingWidth + plan.gutter + plan.trailingWidth <= 783 - CareColumnsPlan.padding)
    }

    @Test func aHingeNearAnEdgeFallsBackToEqualColumns() {
        let plan = CareColumnsPlan.make(width: 900, split: true, fold: 100...140)
        #expect(plan.isSplit)
        #expect(plan.leadingWidth == plan.trailingWidth)
        #expect(plan.gutter == CareColumnsPlan.gutter)
    }

    @Test func listAndDetailSplitAtTheHinge() {
        #expect(CareColumnsPlan.paneSplit(width: 783, split: true, fold: 371.5...411.5) == 391.5)
        #expect(CareColumnsPlan.paneSplit(width: 1000, split: true) == 500)
        #expect(CareColumnsPlan.paneSplit(width: 600, split: true) == nil)
        #expect(CareColumnsPlan.paneSplit(width: 1000, split: false) == nil)
    }

    @Test func onlyRegularWidthWindowsGetColumnsAndTheRail() {
        #expect(openDuo.allowsColumns(typeSize: .large))
        #expect(openDuo.usesSideTabs)
        #expect(!openDuo.allowsColumns(typeSize: .accessibility1), "large text stays in one column")
        var folded = CareWindowMetrics(size: CGSize(width: 466, height: 678))
        #expect(!folded.allowsColumns(typeSize: .large) && !folded.usesSideTabs)
        folded.isRegularWidth = true // the open display in portrait is regular width but only 669 pt wide
        folded.size = CGSize(width: 669, height: 951)
        #expect(!folded.allowsColumns(typeSize: .large) && !folded.usesSideTabs)
    }

    @Test func aDivisionOutsideTheContentIsIgnored() {
        #expect(openDuo.localFold(in: 500...900) == nil)
        let horizontal = CareWindowMetrics(size: CGSize(width: 669, height: 951), divisions: [CGRect(x: 0, y: 455, width: 669, height: 40)])
        #expect(horizontal.localFold(in: 0...669) == nil, "a horizontal hinge (tabletop) does not split columns")
    }
}
