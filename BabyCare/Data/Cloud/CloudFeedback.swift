import Foundation
import Supabase

nonisolated protocol CareFeedbackRemote: Sendable {
    func send(_ draft: CareFeedbackDraft, context: CareFeedbackContext) async throws
}

/// Screenshots go to the private `babycare-feedback` bucket first, then `babycare_send_feedback` records the message
/// (migration 0013). Both steps are safe to repeat with the same draft id.
nonisolated struct SupabaseFeedbackRemote: CareFeedbackRemote {
    static let bucket = "babycare-feedback"
    let client: SupabaseClient

    func send(_ draft: CareFeedbackDraft, context: CareFeedbackContext) async throws {
        struct Params: Encodable, Sendable {
            let p_id: UUID; let p_kind: String; let p_message: String; let p_allow_contact: Bool
            let p_context: CareFeedbackContext; let p_attachments: [String]
        }
        do {
            let userID = try await client.auth.session.user.id
            let paths = draft.attachmentPaths(userID: userID)
            let bucket = client.storage.from(Self.bucket)
            for (path, data) in zip(paths, draft.images) {
                do {
                    _ = try await bucket.upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
                } catch let error as StorageError where error.statusCode == "409" || error.message.lowercased().contains("exists") {
                    // Uploaded by an earlier attempt whose answer was lost.
                }
            }
            _ = try await client.rpc("babycare_send_feedback", params: Params(
                p_id: draft.id, p_kind: draft.kind.rawValue, p_message: draft.trimmedMessage,
                p_allow_contact: draft.allowContact, p_context: context, p_attachments: paths)).execute()
        } catch { throw CloudError.normalize(error) }
    }
}
