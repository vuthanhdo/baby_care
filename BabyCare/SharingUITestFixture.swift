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
        let session = SessionViewModel(consentRemote: Consent(), sharingRemote: Sharing(), defaults: defaults)
        let data = CarePreviewData.make()
        session.openForUITests(userID: me, email: "me@example.invalid", families: [
            CloudFamilySummary(id: ownFamily, name: "Hồ sơ của tôi", revision: 1, role: .owner, createdBy: me, ownerEmail: "me@example.invalid", memberCount: 2),
            CloudFamilySummary(id: sharedFamily, name: "Hồ sơ của tôi", revision: 1, role: .viewer, createdBy: partner, ownerEmail: "grandma@example.invalid", memberCount: 2)
        ], viewModel: BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data))
        return session
    }

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

    private actor Sharing: CareSharingRemote {
        private var invites: [CloudFamilyInvite] = []
        private var partnerRole: CareFamilyRole = .caregiver
        func myFamilies() -> [CloudFamilySummary]? { nil }
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
