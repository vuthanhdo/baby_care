import Foundation
import Observation
import Supabase
import UserNotifications

@MainActor @Observable final class SessionViewModel {
    enum Phase { case starting, signedOut, accountError, consent, content }
    private(set) var phase: Phase = .starting
    private(set) var viewModel: BabyCareViewModel?
    private(set) var email = ""
    private(set) var isLocal = false
    private(set) var busy = false
    private(set) var error: String?
    private(set) var message: String?
    private(set) var needsNewPassword = false
    private(set) var pendingSignupEmail: String?
    /// Families this account belongs to, its own first (migration 0012; older servers list only what RLS shows).
    private(set) var families: [CloudFamilySummary] = []
    private(set) var familyID: UUID?
    /// An invite opened before signing in, joined once the account is ready.
    private(set) var pendingInviteCode: String?
    @ObservationIgnored private lazy var client = CloudConfiguration.makeClient()
    @ObservationIgnored private(set) lazy var consent = ConsentViewModel(remote: consentRemote ?? SupabaseConsentRemote(client: client), store: defaults)
    @ObservationIgnored private let consentRemote: (any ConsentRemote)?
    @ObservationIgnored private let sharingRemote: (any CareSharingRemote)?
    @ObservationIgnored lazy var sharing: any CareSharingRemote = sharingRemote ?? SupabaseSharingRemote(client: client)
    @ObservationIgnored private let makeLocalViewModel: @MainActor () -> BabyCareViewModel
    @ObservationIgnored private var userID: UUID?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    static let callback = URL(string: "babycare://auth-callback")!
    private static let pendingSignupKey = "care.auth.pendingSignupEmail"
    static let pendingInviteKey = "care.invite.pendingCode"

    init(consentRemote: (any ConsentRemote)? = nil, sharingRemote: (any CareSharingRemote)? = nil, defaults: UserDefaults = .standard,
         makeLocalViewModel: @escaping @MainActor () -> BabyCareViewModel = { AppDependencies.makeViewModel() }) {
        self.consentRemote = consentRemote; self.sharingRemote = sharingRemote
        self.defaults = defaults; self.makeLocalViewModel = makeLocalViewModel
        pendingSignupEmail = defaults.string(forKey: Self.pendingSignupKey)
        pendingInviteCode = defaults.string(forKey: Self.pendingInviteKey)
    }

    var currentFamily: CloudFamilySummary? { families.first { $0.id == familyID } }
    /// The signed-in member's role in the open family; device storage is always the owner's.
    var role: CareFamilyRole { isLocal ? .owner : currentFamily?.role ?? .owner }
    var canShare: Bool { !isLocal && userID != nil && phase == .content }
    /// The family created by this account, which it can never leave.
    var isOwnFamily: Bool { currentFamily.map { $0.createdBy == userID } ?? true }

    /// How a family is named in the picker: one's own, or whose it is.
    func title(of family: CloudFamilySummary) -> String {
        if family.createdBy == userID { return L10n.text("Gia đình của tôi") }
        return family.ownerEmail.isEmpty ? L10n.text("Gia đình được chia sẻ") : L10n.text("Gia đình của {0}", family.ownerEmail)
    }

    func start(events suppliedEvents: AsyncStream<(event: AuthChangeEvent, session: Session?)>? = nil) {
        guard listener == nil else { return }
        let events = suppliedEvents ?? client.auth.authStateChanges
        listener = Task { [weak self] in
            for await (event, session) in events {
                guard !Task.isCancelled, let self else { return }
                if event == .passwordRecovery { needsNewPassword = true }
                if session?.user.id == userID, phase != .starting { continue }
                await accept(session)
            }
        }
    }

    deinit { listener?.cancel() }

    private func detach() async -> Int {
        generation += 1
        let ticket = generation
        let old = viewModel; viewModel = nil
        await old?.deactivate()
        guard generation == ticket else { return ticket }
        // These notifications belong to this app, not to another installed app.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        return ticket
    }
    func openDevice() async {
        let ticket = await detach(); guard generation == ticket else { return }
        defaults.set("device", forKey: "care.mode")
        await accept(client.auth.currentSession)
        if userID == nil {
            message = L10n.text("Đã chọn dữ liệu trên máy. Hãy đăng nhập để ghi nhận sự đồng ý trước khi tiếp tục; dữ liệu của bé không tự tải lên cloud.")
        }
    }
    func openCloud() async {
        let ticket = await detach(); guard generation == ticket else { return }
        isLocal = false; userID = nil
        defaults.set("cloud", forKey: "care.mode")
        await accept(client.auth.currentSession)
    }
    private func accept(_ session: Session?) async {
        let ticket = await detach(); guard generation == ticket else { return }
        consent.reset()
        consent.userKey = session?.user.id.uuidString
        userID = session?.user.id; email = session?.user.email ?? ""
        families = []; familyID = nil
        isLocal = defaults.string(forKey: "care.mode") == "device"
        error = nil
        guard session != nil else { phase = .signedOut; return }
        pendingSignupEmail = nil
        defaults.removeObject(forKey: Self.pendingSignupKey)
        // Keep the splash visible while the previous family is restored. Publishing
        // `.accountError` here makes the family picker flash on every app launch.
        phase = .starting
        let valid = await consent.refresh()
        guard generation == ticket else { return }
        guard valid else { phase = .consent; return }
        await continueAfterConsent()
    }
    func completeConsent() async {
        let ticket = generation
        guard await consent.submit(), generation == ticket else { return }
        await continueAfterConsent()
    }
    func checkConsent() async {
        guard userID != nil, !busy, !consent.busy else { return }
        let ticket = generation
        let valid = await consent.refresh()
        guard generation == ticket else { return }
        if valid {
            if phase == .consent { await continueAfterConsent() }
        } else {
            let detached = await detach()
            guard generation == detached else { return }
            phase = .consent
        }
    }
    private func continueAfterConsent() async {
        guard consent.isAccepted else { phase = .consent; return }
        if isLocal {
            viewModel = makeLocalViewModel(); phase = .content; busy = false
        } else { await loadAccount() }
    }
    func loadAccount() async {
        guard let userID else { return }
        guard consent.isAccepted else { phase = .consent; return }
        let ticket = generation
        busy = true; error = nil
        defer { if generation == ticket { busy = false } }
        do {
            guard try await client.auth.session.user.id == userID else { throw CloudError.signedOut }
            let result = try await listFamilies(userID: userID)
            guard generation == ticket else { return }
            families = result
            let key = "care.family.\(userID)"
            if let code = pendingInviteCode, await join(code: code, ticket: ticket) {
                return
            } else if generation != ticket {
                return
            } else if let last = defaults.string(forKey: key), let family = result.first(where: { $0.id.uuidString.caseInsensitiveCompare(last) == .orderedSame }) {
                await selectFamily(family.id)
            } else if let first = result.first {
                await selectFamily(first.id)
            } else {
                // A stable ID makes automatic setup retryable after network interruption.
                struct Params: Encodable { let p_id: UUID; let p_name: String }
                let id: UUID = try await client.rpc("babycare_create_family", params: Params(p_id: userID, p_name: "Hồ sơ của tôi")).execute().value
                guard generation == ticket else { return }
                families = (try? await listFamilies(userID: userID)) ?? []
                guard generation == ticket else { return }
                await selectFamily(id)
            }
        } catch {
            guard generation == ticket else { return }
            let normalized = CloudError.normalize(error)
            if normalized as? CloudError == .consentRequired {
                consent.reset(); consent.userKey = userID.uuidString; _ = await consent.refresh()
                guard generation == ticket else { return }
                phase = .consent; return
            }
            if normalized as? CloudError == .offline,
               let value = defaults.string(forKey: "care.family.\(userID)"), let id = UUID(uuidString: value) {
                await selectFamily(id) // Provider only returns this account's confirmed cache on network errors.
            } else {
                self.error = normalized.localizedDescription
                phase = .accountError
            }
        }
    }
    func selectFamily(_ id: UUID) async {
        guard let userID else { return }
        guard consent.isAccepted else { phase = .consent; return }
        let ticket = await detach(); guard generation == ticket else { return }
        let remote = SupabaseRemote(authClient: client, userID: userID, familyID: id)
        let provider = SupabaseCareDataProvider(remote: remote, cache: SwiftDataCloudCache(userID: userID, familyID: id), familyID: id)
        familyID = id
        viewModel = BabyCareViewModel(provider: provider, notifications: LocalCareReminderService(scope: "cloud.\(userID.uuidString).\(id.uuidString)"),
                                      reviews: CareReviewTracker(), access: families.first { $0.id == id }?.role ?? .owner)
        defaults.set(id.uuidString, forKey: "care.family.\(userID)")
        phase = .content; busy = false
    }

    private func listFamilies(userID: UUID) async throws -> [CloudFamilySummary] {
        if let families = try await sharing.myFamilies() { return families }
        // A server without migration 0012: every family RLS shows was created by this account.
        var result: [CloudFamily] = []; var offset = 0
        while true {
            let page: [CloudFamily] = try await client.from("families").select().order("id").range(from: offset, to: offset + 199).execute().value
            result += page
            if page.count < 200 { break }; offset += 200
        }
        return result.map { CloudFamilySummary(id: $0.id, name: $0.name, revision: $0.revision, role: .owner, createdBy: userID, ownerEmail: email, memberCount: 1) }
    }

    /// Opens another family this account belongs to.
    func switchFamily(_ id: UUID) async {
        guard id != familyID, families.contains(where: { $0.id == id }) else { return }
        await selectFamily(id)
    }

    /// Re-reads the family list (members, roles) without leaving the open family.
    func refreshFamilies() async {
        guard let userID, !isLocal, let list = try? await listFamilies(userID: userID), self.userID == userID else { return }
        families = list
    }

    /// Joins with a code typed in Settings. Returns why it failed, or nil once the family is open.
    func joinFamily(code: String) async -> String? {
        let normalized = CareInviteCode.normalize(code)
        guard CareInviteCode.isComplete(normalized) else { return L10n.text("Mã mời gồm 8 chữ và số.") }
        guard !isLocal, userID != nil else { remember(invite: normalized); return L10n.text("Hãy đăng nhập tài khoản cloud để tham gia gia đình.") }
        guard !busy else { return CloudError.busy.localizedDescription }
        busy = true; error = nil; message = nil
        defer { busy = false }
        let ticket = generation
        do {
            let answer = try await sharing.acceptInvite(code: normalized)
            guard generation == ticket else { return nil }
            if let problem = answer.problem { return problem }
            return await open(answer, ticket: ticket) ? nil : L10n.text("Đã tham gia nhưng chưa mở được gia đình. Hãy tải lại.")
        } catch {
            return CloudError.normalize(error).localizedDescription
        }
    }

    /// A pending invite after sign-in: join, then open the family. False when nothing was opened.
    private func join(code: String, ticket: Int) async -> Bool {
        forgetInvite()
        do {
            let answer = try await sharing.acceptInvite(code: code)
            guard generation == ticket else { return false }
            if let problem = answer.problem { error = problem; return false }
            return await open(answer, ticket: ticket)
        } catch {
            guard generation == ticket else { return false }
            self.error = CloudError.normalize(error).localizedDescription
            return false
        }
    }

    private func open(_ answer: CloudInviteAnswer, ticket: Int) async -> Bool {
        guard let userID, let id = answer.familyID else { return false }
        forgetInvite()
        families = (try? await listFamilies(userID: userID)) ?? families
        guard generation == ticket, families.contains(where: { $0.id == id }) else { return false }
        await selectFamily(id)
        let who = answer.ownerEmail.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.text("người mời")
        let text = answer.status == .joined ? L10n.text("Đã tham gia gia đình của {0}.", who) : L10n.text("Bạn đã ở trong gia đình của {0}.", who)
        message = text
        await viewModel?.send(.showMessage(text))
        return true
    }

    private func remember(invite code: String) {
        pendingInviteCode = code; defaults.set(code, forKey: Self.pendingInviteKey)
    }
    private func forgetInvite() {
        pendingInviteCode = nil; defaults.removeObject(forKey: Self.pendingInviteKey)
    }

    /// Leaves a family someone else created and opens this account's own family.
    func leaveFamily(_ id: UUID) async -> String? {
        guard let userID, !busy else { return nil }
        busy = true; error = nil
        do {
            try await sharing.leaveFamily(familyID: id)
        } catch {
            busy = false
            return CloudError.normalize(error).localizedDescription
        }
        if defaults.string(forKey: "care.family.\(userID)")?.caseInsensitiveCompare(id.uuidString) == .orderedSame {
            defaults.removeObject(forKey: "care.family.\(userID)")
        }
        busy = false
        await loadAccount()
        return nil
    }

    #if DEBUG
    /// UI tests: a signed-in cloud session over fake transports, without Supabase (`SharingUITestFixture`).
    func openForUITests(userID: UUID, email: String, families: [CloudFamilySummary], viewModel: BabyCareViewModel) {
        self.userID = userID; self.email = email; isLocal = false
        self.families = families; familyID = families.first?.id
        consent.userKey = userID.uuidString
        self.viewModel = viewModel; phase = .content
    }
    #endif

    /// The open family became unreadable, usually because the owner removed this member: open another one.
    func recoverFromLostAccess(_ reason: String) async {
        guard let userID, !isLocal else { return }
        defaults.removeObject(forKey: "care.family.\(userID)")
        await loadAccount()
        message = reason
        if phase == .content { await viewModel?.send(.showMessage(reason)) }
    }
    enum AuthAction { case signIn, signUp, resetPassword }
    func authenticate(_ action: AuthAction, email: String, password: String, confirmation: String = "", captchaToken: String? = nil) async {
        guard !busy else { return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validation = AuthValidation.emailError(email) { error = validation; return }
        if case .signUp = action {
            if let validation = AuthValidation.signupError(password: password, confirmation: confirmation) { error = validation; return }
            guard !AuthCaptchaConfiguration.isEnabled || AuthCaptchaConfiguration.pageURL != nil else { error = L10n.text("Đăng ký chưa khả dụng: cần cấu hình xác minh chống spam."); return }
        }
        if AuthCaptchaConfiguration.isEnabled && (captchaToken?.isEmpty ?? true) {
            error = L10n.text("Vui lòng hoàn tất xác minh chống spam."); return
        }
        do {
            switch action {
            case .signIn:
                _ = try await client.auth.signIn(email: email, password: password, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
            case .signUp:
                let response = try await client.auth.signUp(email: email, password: password, redirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
                switch Self.signupOutcome(hasSession: response.session != nil, identityCount: response.user.identities?.count) {
                case .signedIn: break
                case .existingAccount:
                    self.error = L10n.text("Email này đã có tài khoản. Hãy đăng nhập hoặc dùng Quên mật khẩu.")
                case .confirmationPending:
                    pendingSignupEmail = email
                    defaults.set(email, forKey: Self.pendingSignupKey)
                    message = L10n.text("Đã gửi email tới {0}. Bấm liên kết trong email để xác minh tài khoản.", "\(email)")
                }
            case .resetPassword:
                try await client.auth.resetPasswordForEmail(email, redirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
                message = L10n.text("Nếu tài khoản tồn tại, bạn sẽ nhận được email đặt lại mật khẩu.")
            }
        } catch { self.error = authMessage(error) }
    }
    func resendSignupConfirmation(captchaToken: String? = nil) async {
        guard !busy, let email = pendingSignupEmail else { return }
        guard !AuthCaptchaConfiguration.isEnabled || !(captchaToken?.isEmpty ?? true) else { error = L10n.text("Vui lòng hoàn tất xác minh chống spam."); return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        do {
            try await client.auth.resend(email: email, type: .signup, emailRedirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
            message = L10n.text("Đã gửi lại email xác thực tới {0}.", "\(email)")
        } catch { self.error = authMessage(error) }
    }
    func cancelSignupVerification() {
        pendingSignupEmail = nil; defaults.removeObject(forKey: Self.pendingSignupKey)
        error = nil; message = nil
    }
    func signInWithGoogle() async {
        guard !busy else { return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        do {
            _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: Self.callback)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession", nsError.code == 1 { return }
            self.error = L10n.text("Không thể đăng nhập bằng Google. Hãy thử lại hoặc dùng email và mật khẩu.")
        }
    }
    /// Native Sign in with Apple: the identity token from AuthenticationServices is exchanged for a Supabase
    /// session; the auth listener then moves the app on exactly as for the other providers.
    func signInWithApple(idToken: String, nonce: String, authorizationCode: String? = nil) async {
        guard !busy else { return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        do {
            _ = try await client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
            if let authorizationCode { await linkAppleToken(code: authorizationCode) }
        } catch { appleSignInFailed() }
    }
    /// Stores Apple's refresh token server-side (apple-token Edge Function) so it can be revoked when the
    /// account is deleted, as App Store Review Guideline 5.1.1(v) requires. Best effort: sign-in already succeeded.
    private func linkAppleToken(code: String) async {
        try? await client.functions.invoke("apple-token", options: .init(body: ["action": "link", "code": code]))
    }
    func appleSignInFailed() {
        error = L10n.text("Không thể đăng nhập bằng Apple. Hãy thử lại hoặc dùng email và mật khẩu.")
    }
    func handleCallback(_ url: URL) async {
        if let code = CareInviteCode.code(from: url) {
            guard phase == .content, !isLocal, userID != nil else {
                remember(invite: code)
                message = L10n.text("Đăng nhập tài khoản cloud để tham gia gia đình bằng mã {0}.", CareInviteCode.display(code))
                return
            }
            if let problem = await joinFamily(code: code) {
                error = problem
                await viewModel?.send(.showMessage(problem))
            }
            return
        }
        guard url.scheme == "babycare", url.host == "auth-callback" else { return }
        do { _ = try await client.auth.session(from: url) }
        catch { self.error = L10n.text("Liên kết không còn hiệu lực. Hãy yêu cầu email mới.") }
    }
    func updatePassword(_ password: String) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        if let validation = AuthValidation.passwordError(password) { error = validation; return }
        do { _ = try await client.auth.update(user: UserAttributes(password: password)); needsNewPassword = false; message = L10n.text("Đã đổi mật khẩu.") }
        catch { self.error = authMessage(error) }
    }
    func signOut() async {
        consent.reset()
        let ticket = await detach(); guard generation == ticket else { return }
        userID = nil; email = ""; isLocal = false; phase = .signedOut
        needsNewPassword = false; pendingSignupEmail = nil; defaults.removeObject(forKey: Self.pendingSignupKey)
        error = nil; busy = true
        defaults.set("cloud", forKey: "care.mode")
        defer { busy = false }
        do { try await client.auth.signOut(scope: .local) }
        catch { message = L10n.text("Đã thoát trên thiết bị. Chưa liên hệ được server để thu hồi phiên từ xa.") }
    }
    @discardableResult
    func deleteAccount() async -> Bool {
        guard !busy, !isLocal, let deletingUserID = userID else { return false }
        busy = true; error = nil; message = nil
        do {
            // Revoke the Sign in with Apple token first; the auth user (and its token row) disappears below.
            try? await client.functions.invoke("apple-token", options: .init(body: ["action": "revoke"]))
            // A family someone else also uses is handed over by the server with its photos; Storage refuses them too.
            try await CloudPrivacyDeletion.removeOwnedAccountMedia(client: client, userID: deletingUserID,
                                                                   keeping: Set(families.filter { $0.memberCount > 1 }.map(\.id)))
            _ = try await client.rpc("babycare_delete_account").execute()
            let ticket = await detach()
            guard generation == ticket else { busy = false; return false }
            let cacheRoot = URL.applicationSupportDirectory
                .appending(path: "BabyCare/Cloud/cxlqvuqloaokzmaewvdy/\(deletingUserID.uuidString)", directoryHint: .isDirectory)
            try? FileManager.default.removeItem(at: cacheRoot)
            defaults.removeObject(forKey: "care.family.\(deletingUserID)")
            defaults.removeObject(forKey: Self.pendingSignupKey)
            defaults.set("cloud", forKey: "care.mode")
            userID = nil; email = ""; isLocal = false; needsNewPassword = false
            pendingSignupEmail = nil; phase = .signedOut; busy = false
            consent.reset()
            try? await client.auth.signOut(scope: .local)
            return true
        } catch {
            self.error = CloudError.normalize(error).localizedDescription
            busy = false
            return false
        }
    }
    nonisolated enum SignupOutcome: Equatable { case signedIn, confirmationPending, existingAccount }

    /// Supabase keeps email enumeration protection on: signing up with an email that already has a confirmed
    /// account answers 200 with no session, no email and an empty `identities` array instead of an error.
    /// Treat that shape as "existing account" so the UI does not wait for a confirmation email that never comes.
    nonisolated static func signupOutcome(hasSession: Bool, identityCount: Int?) -> SignupOutcome {
        if hasSession { return .signedIn }
        if let identityCount, identityCount == 0 { return .existingAccount }
        return .confirmationPending
    }

    private func authMessage(_ error: Error) -> String {
        if error is URLError { return L10n.text("Không kết nối được dịch vụ đăng nhập. Hãy kiểm tra mạng.") }
        return L10n.text("Chưa hoàn tất đăng nhập. Kiểm tra email, mật khẩu hoặc xác nhận email. Nếu gửi email thất bại, hãy thử lại sau hoặc kiểm tra cấu hình gửi email của project.")
    }
}
