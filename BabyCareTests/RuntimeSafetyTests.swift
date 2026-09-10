import Foundation
import Testing
import Supabase
import UIKit
@testable import BabyCare

@MainActor struct RuntimeSafetyTests {
    @Test func waitingAuthListenerDoesNotRetainSession() async {
        let (events, continuation) = AsyncStream<(event: AuthChangeEvent, session: Session?)>.makeStream()
        defer { continuation.finish() }
        var model: SessionViewModel? = SessionViewModel()
        weak var reference = model
        model?.start(events: events)
        // Let the listener enter its suspension point before releasing its owner.
        for _ in 0..<20 { await Task.yield() }
        model = nil
        #expect(reference == nil)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, 1e30, 1.5, 0])
    func malformedCloudVersionThrows(_ value: Double) {
        let row: CloudRow = ["id": .id(UUID()), "version": .number(value), "deleted_at": .null]
        #expect(throws: CareDataError.self) {
            try CloudMapping.decode(["babies": [row]], revision: 1, selected: nil)
        }
    }

    @Test(arguments: [Double.nan, .infinity, 1e30, 1.5, 0, 6 * 1024 * 1024])
    func malformedMediaSizeThrows(_ value: Double) {
        let row: CloudRow = ["id": .id(UUID()), "version": .number(1), "deleted_at": .null,
            "purpose": .string("avatar"), "mime_type": .string("image/jpeg"),
            "object_path": .string("test"), "byte_count": .number(value)]
        #expect(throws: CareDataError.self) {
            try CloudMapping.decode(["media_assets": [row]], revision: 1, selected: nil)
        }
    }

    @Test func duplicateCloudIDsAreRejected() {
        let row: CloudRow = ["id": .id(UUID()), "version": .number(1), "deleted_at": .null]
        #expect(throws: CareDataError.self) {
            try CloudMapping.decode(["babies": [row, row]], revision: 1, selected: nil)
        }
    }

    @Test func duplicateCachedIDsDoNotTrapMediaComparison() {
        let baby = BabyData(profile: BabyProfile())
        let invalid = CareDatabase(babies: [baby, baby])
        #expect(CloudMediaPlan.hasChanges(from: invalid, to: invalid))
    }

    @Test func nonfiniteStatisticsAreExcluded() {
        #expect(InsightData.number("nan") == nil)
        #expect(InsightData.number("inf") == nil)
        #expect(InsightData.number("38,2") == 38.2)
        let entry = CareActivity(kind: .milk, value: "1e308", unit: "ml")
        #expect(InsightData.sum([entry, entry], kind: .milk, unit: "ml") == nil)
    }

    @Test func imagesHaveBoundedPixelDimensionsAndInvalidDataIsRejected() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 1800), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3200, height: 1800))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.9))
        let activity = try #require(CareImageProcessor.jpeg(data).flatMap(UIImage.init(data:)))
        #expect(activity.size == CGSize(width: 1600, height: 900))
        let avatar = try #require(CareImageProcessor.jpeg(data, avatar: true).flatMap(UIImage.init(data:)))
        #expect(avatar.size == CGSize(width: 400, height: 400))
        #expect(CareImageProcessor.jpeg(Data("invalid".utf8)) == nil)
    }

    @Test(arguments: [false, true])
    func lateStorageStatusCannotRestoreDeactivatedState(commit: Bool) async {
        let provider = SuspendedStatusProvider()
        let model = BabyCareViewModel(provider: provider, initialData: commit ? CareDatabase() : nil)
        let operation = Task {
            await model.send(commit ? .commit(.createBaby(BabyProfile()), message: "Saved") : .load)
        }
        while await !provider.waiting { await Task.yield() }
        await model.deactivate()
        await provider.release()
        #expect(await operation.value == false)
        #expect(model.state.phase == .idle)
        #expect(model.babies.isEmpty)
        #expect(model.state.toast == nil)
        #expect(model.state.storage == .device)
    }
}

private actor SuspendedStatusProvider: CareDataProvider {
    private var continuation: CheckedContinuation<Void, Never>?
    var waiting: Bool { continuation != nil }
    func release() { continuation?.resume(); continuation = nil }
    func load() async throws -> CareDatabase { CareDatabase(babies: [BabyData(profile: BabyProfile())]) }
    func apply(_ mutation: CareDataMutation) async throws -> CareDatabase { try await load() }
    func status() async -> CareStorageStatus {
        await withCheckedContinuation { continuation = $0 }
        return .cloud
    }
}
