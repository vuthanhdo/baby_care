import Foundation
import PDFKit
import Testing
@testable import BabyCare

@MainActor
struct GrowthLoopTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func reviewWaitsForEngagementAndAsksOncePerVersion() {
        var policy = CareReviewPolicy()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        policy.recordSaved(entries: 20, at: day, calendar: utc)
        policy.recordSaved(entries: 3, at: day.addingTimeInterval(3_600), calendar: utc)
        #expect(policy.savedEntries == 23 && policy.activeDays == 1)
        let oneDay = policy.shouldAsk(after: .illnessEnded, version: "1.2")
        #expect(!oneDay) // plenty of entries, but one day
        policy.recordSaved(entries: 0, at: day.addingTimeInterval(86_400), calendar: utc)
        #expect(policy.activeDays == 1) // nothing saved, no new day
        policy.recordSaved(entries: 1, at: day.addingTimeInterval(86_400), calendar: utc)
        policy.recordSaved(entries: 1, at: day.addingTimeInterval(2 * 86_400), calendar: utc)
        #expect(policy.activeDays == 3)
        let first = policy.shouldAsk(after: .illnessEnded, version: "1.2")
        let again = policy.shouldAsk(after: .reportShared, version: "1.2")
        let nextVersion = policy.shouldAsk(after: .reportShared, version: "1.3")
        #expect(first && !again && nextVersion)
    }

    @Test func reviewNeedsEnoughEntries() {
        var policy = CareReviewPolicy()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for offset in 0..<5 { policy.recordSaved(entries: 2, at: day.addingTimeInterval(Double(offset) * 86_400), calendar: utc) }
        #expect(policy.activeDays == 5 && policy.savedEntries == 10)
        let ask = policy.shouldAsk(after: .illnessEnded, version: "1.2")
        #expect(!ask)
    }

    @Test func endingAnIllnessAsksForAReviewOnlyOnce() async throws {
        let suite = "GrowthLoopTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engaged = CareReviewPolicy(savedEntries: 30, activeDays: 4)
        defaults.set(try JSONEncoder().encode(engaged), forKey: CareReviewTracker.key)
        let data = CarePreviewData.make()
        let viewModel = BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data,
                                          reviews: CareReviewTracker(defaults: defaults, version: "1.2"))
        let baby = viewModel.baby.id

        #expect(await viewModel.send(.commit(.saveActivities(babyID: baby, entries: [CareActivity(kind: .diaper, value: "Đi tiểu")]))))
        #expect(viewModel.reviewRequests == 0) // logging is counted, not a moment to ask
        #expect(await viewModel.send(.commit(.endIllness(babyID: baby))))
        #expect(viewModel.reviewRequests == 1)
        viewModel.noteReviewMoment(.reportShared)
        #expect(viewModel.reviewRequests == 1) // already asked in this version

        // The count survives a relaunch.
        #expect(CareReviewTracker(defaults: defaults, version: "1.2").policy.savedEntries == 31)
    }

    @Test func demoAndTestViewModelsNeverAsk() async {
        let viewModel = BabyCareViewModel.preview()
        #expect(await viewModel.send(.commit(.endIllness(babyID: viewModel.baby.id))))
        viewModel.noteReviewMoment(.reportShared)
        #expect(viewModel.reviewRequests == 0)
    }

    @Test func appStoreLinkCarriesTheCampaign() throws {
        let link = CareAppStore.link(campaign: "pdf-report")
        let components = try #require(URLComponents(url: link, resolvingAgainstBaseURL: false))
        #expect(components.host == "apps.apple.com" && components.path == "/app/apple-store/id6824822487")
        #expect(components.queryItems == [.init(name: "pt", value: "129617549"), .init(name: "ct", value: "pdf-report"), .init(name: "mt", value: "8")])
    }

    @Test func reportEndsWithTheAppQRCode() throws {
        let viewModel = BabyCareViewModel.preview()
        let snapshot = CareReportSnapshot(viewModel: viewModel, interval: DateInterval(start: Date().addingTimeInterval(-172_800), end: Date()),
                                          sections: Set(ReportSection.allCases))
        let url = try CareReportPDF.create(snapshot)
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try #require(PDFDocument(url: url)?.string)
        #expect(text.contains(L10n.text("Tạo bằng ứng dụng Bé Khỏe")))
        #expect(text.contains(L10n.text("Quét mã để tải miễn phí trên App Store")))
        let code = try #require(CareReportPDF.qrCode(CareAppStore.link(campaign: "pdf-report"), side: 64))
        #expect(abs(code.size.width - 256) < 2) // 4× the 64 pt it is drawn at
    }
}
