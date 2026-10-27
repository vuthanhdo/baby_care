#if DEBUG
import Foundation

/// `-ui-testing-sharing`: a signed-in cloud session whose sharing calls answer from memory, so UI tests reach
/// Settings → Gia đình & chia sẻ. Never contacts Supabase; the family data is the small demo fixture.
@MainActor enum SharingUITestFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing-sharing") }
    static let me = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!
    static let partner = UUID(uuidString: "00000000-0000-0000-0000-0000000000a2")!
    static let ownFamily = UUID(uuidString: "00000000-0000-0000-0000-00000000aa10")!
    static let sharedFamily = UUID(uuidString: "00000000-0000-0000-0000-00000000bb10")!
    static let code = "ABCD2345"

    static func makeSession() -> SessionViewModel {
        let defaults = UserDefaults(suiteName: "BabyCare.SharingUITests")!
        defaults.removePersistentDomain(forName: "BabyCare.SharingUITests")
        let session = SessionViewModel(consentRemote: Consent(), sharingRemote: Sharing(), feedbackRemote: Feedback(),
                                       featureRemote: Features(), defaults: defaults)
        let data = CarePreviewData.make()
        session.openForUITests(userID: me, email: "me@example.invalid", families: families,
                               viewModel: BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data))
        return session
    }

    nonisolated static let families = [
        CloudFamilySummary(id: ownFamily, name: "Hồ sơ của tôi", revision: 1, role: .owner, createdBy: me, ownerEmail: "me@example.invalid", memberCount: 2),
        CloudFamilySummary(id: sharedFamily, name: "Hồ sơ của tôi", revision: 1, role: .viewer, createdBy: partner, ownerEmail: "grandma@example.invalid", memberCount: 2)
    ]

    private actor Consent: ConsentRemote {
        func status() -> ConsentStatus {
            let stamp = "2026-10-26T08:00:00Z"
            let versions = ConsentVersions.bundled
            return ConsentStatus(required: versions, accepted: ConsentRecord(
                terms_version: versions.terms_version, privacy_version: versions.privacy_version,
                health_version: versions.health_version, terms_accepted_at: stamp, privacy_accepted_at: stamp,
                health_accepted_at: stamp, representative_confirmed: true, representative_confirmed_at: stamp,
                created_at: stamp), valid: true)
        }
        func accept(versions: ConsentVersions) -> ConsentStatus { status() }
    }

    /// Accepts any feedback after a short delay, like a successful upload; a message containing "lỗi mạng" fails once.
    private actor Feedback: CareFeedbackRemote {
        private var failed = false
        func send(_ draft: CareFeedbackDraft, context: CareFeedbackContext) async throws {
            try await Task.sleep(for: .milliseconds(300))
            if draft.message.contains("lỗi mạng") && !failed { failed = true; throw CloudError.offline }
        }
    }

    /// A board with an open, a planned (already voted) and a shipped suggestion; new ones wait for review.
    private actor Features: CareFeatureRemote {
        private var items: [CareFeatureRequest] = [
            CareFeatureRequest(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000e1")!, title: "Nhắc bé uống nước",
                               details: "Nhắc mỗi 2 giờ khi bé ốm", status: .open, votes: 12, voted: false, mine: false),
            CareFeatureRequest(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000e2")!, title: "Xuất dữ liệu ra Excel",
                               details: "", status: .planned, votes: 7, voted: true, mine: false),
            CareFeatureRequest(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000e3")!, title: "Giao diện tối",
                               details: "Dịu mắt khi cho bé bú đêm", status: .done, votes: 20, voted: false, mine: false)
        ]
        func board() -> [CareFeatureRequest] {
            items.sorted { ($0.status == .pending ? 1 : 0, $0.votes) > ($1.status == .pending ? 1 : 0, $1.votes) }
        }
        func submit(id: UUID, title: String, details: String) {
            guard !items.contains(where: { $0.id == id }) else { return }
            items.append(CareFeatureRequest(id: id, title: title, details: details, status: .pending, votes: 1, voted: true, mine: true))
        }
        func toggleVote(id: UUID) throws -> CareFeatureVote {
            guard let index = items.firstIndex(where: { $0.id == id }), items[index].status.votable else {
                throw CloudError.rejected("Not open for votes")
            }
            items[index].voted.toggle()
            items[index].votes += items[index].voted ? 1 : -1
            return CareFeatureVote(voted: items[index].voted, votes: items[index].votes)
        }
        func report(id: UUID) {}
    }

    private actor Sharing: CareSharingRemote {
        private var invites: [CloudFamilyInvite] = []
        private var partnerRole: CareFamilyRole = .caregiver
        // Never nil: nil sends the session to the real `families` table, which hangs without a real session.
        func myFamilies() -> [CloudFamilySummary]? { SharingUITestFixture.families }
        func sharing(familyID: UUID) -> CloudFamilySharing {
            CloudFamilySharing(role: .owner, createdBy: SharingUITestFixture.me, members: [
                CloudFamilyMember(userID: SharingUITestFixture.me, email: "me@example.invalid", role: .owner, joinedAt: Date(timeIntervalSince1970: 1_790_000_000)),
                CloudFamilyMember(userID: SharingUITestFixture.partner, email: "partner@example.invalid", role: partnerRole, joinedAt: Date(timeIntervalSince1970: 1_790_100_000))
            ], invites: invites)
        }
        func createInvite(familyID: UUID, role: CareFamilyRole) -> CloudCreatedInvite {
            let invite = CloudFamilyInvite(id: UUID(), role: role, expiresAt: Date().addingTimeInterval(48 * 3600))
            invites.append(invite)
            return CloudCreatedInvite(invite: invite, code: SharingUITestFixture.code)
        }
        func acceptInvite(code: String) -> CloudInviteAnswer { CloudInviteAnswer(status: .invalid) }
        func revokeInvite(id: UUID) { invites.removeAll { $0.id == id } }
        func setRole(familyID: UUID, userID: UUID, role: CareFamilyRole) { partnerRole = role }
        func removeMember(familyID: UUID, userID: UUID) {}
        func leaveFamily(familyID: UUID) {}
    }
}
#endif
