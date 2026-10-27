import Foundation
import Supabase
import Testing
@testable import BabyCare

@MainActor
struct FeedbackTests {
    @Test func draftNeedsAMessageWithinLimits() {
        var draft = CareFeedbackDraft()
        #expect(!draft.canSend)
        draft.message = "   \n "
        #expect(!draft.canSend)
        draft.message = "  Biểu đồ trống  "
        #expect(draft.canSend && draft.trimmedMessage == "Biểu đồ trống")
        draft.message = String(repeating: "a", count: CareFeedbackDraft.maximumLength + 1)
        #expect(!draft.canSend)
        draft.message = "ok"
        draft.images = Array(repeating: Data([0xff]), count: CareFeedbackDraft.maximumImages + 1)
        #expect(!draft.canSend)
    }

    @Test func screenshotsLiveInTheSendersFolder() {
        var draft = CareFeedbackDraft(id: UUID(uuidString: "00000000-0000-0000-0000-00000000FB01")!)
        draft.images = [Data([1]), Data([2])]
        let user = UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!
        // Lower case, as Postgres prints UUIDs: the RPC compares the folder names with auth.uid()::text.
        #expect(draft.attachmentPaths(userID: user) == ["00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb01/0.jpg",
                                                        "00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb01/1.jpg"])
    }

    @Test func contextDescribesTheAppAndDeviceOnly() throws {
        let context = CareFeedbackContext.current(storage: "cloud")
        #expect(!context.app_version.isEmpty && !context.os_version.isEmpty && !context.device.isEmpty)
        #expect(context.summary.contains(context.device) && context.summary.contains("cloud"))
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: String])
        #expect(Set(json.keys) == ["app_version", "build", "os_version", "device", "language", "storage"])
    }

    @Test func featureBoardDecodesAndKnowsWhatTakesVotes() throws {
        let board = try JSONDecoder().decode([CareFeatureRequest].self, from: Data("""
        [{"id":"00000000-0000-0000-0000-0000000000d1","title":"Water reminders","details":"","status":"pending","votes":1,"voted":true,"mine":true,"created_at":"2026-10-27T10:00:00.123456+00:00"},
         {"id":"00000000-0000-0000-0000-0000000000d2","title":"Night mode","details":"Dim","status":"done","votes":20,"voted":false,"mine":false,"created_at":"2026-10-27T10:00:00+00:00"}]
        """.utf8))
        #expect(board.map(\.status) == [.pending, .done] && board[1].votes == 20)
        #expect(!CareFeatureStatus.pending.isPublished && !CareFeatureStatus.pending.votable)
        #expect(CareFeatureStatus.open.votable && CareFeatureStatus.planned.votable && !CareFeatureStatus.done.votable)
        #expect(CareFeatureStatus.done.isPublished && !CareFeatureStatus.declined.isPublished)
        let vote = try JSONDecoder().decode(CareFeatureVote.self, from: Data(#"{"voted":true,"votes":13}"#.utf8))
        #expect(vote == CareFeatureVote(voted: true, votes: 13))
        guard case .rejected = CloudError.normalize(PostgrestError(code: "P0001", message: "Not open for votes")) as? CloudError else {
            Issue.record("a closed suggestion should explain itself"); return
        }
    }

    @Test func tooMuchFeedbackIsExplained() {
        guard case .rejected(let reason) = CloudError.normalize(PostgrestError(code: "P0001", message: "Too much feedback")) as? CloudError else {
            Issue.record("the hourly limit should be a refusal with a reason"); return
        }
        #expect(reason.contains("10"))
    }
}
