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
    @ObservationIgnored private lazy var client = CloudConfiguration.makeClient()
    @ObservationIgnored private(set) lazy var consent = ConsentViewModel(remote: consentRemote ?? SupabaseConsentRemote(client: client), store: defaults)
    @ObservationIgnored private let consentRemote: (any ConsentRemote)?
    @ObservationIgnored private let makeLocalViewModel: @MainActor () -> BabyCareViewModel
    @ObservationIgnored private var userID: UUID?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    static let callback = URL(string: "babycare://auth-callback")!
    private static let pendingSignupKey = "care.auth.pendingSignupEmail"

    init(consentRemote: (any ConsentRemote)? = nil, defaults: UserDefaults = .standard,
         makeLocalViewModel: @escaping @MainActor () -> BabyCareViewModel = { AppDependencies.makeViewModel() }) {
        self.consentRemote = consentRemote; self.defaults = defaults; self.makeLocalViewModel = makeLocalViewModel
        pendingSignupEmail = defaults.string(forKey: Self.pendingSignupKey)
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
            var result: [CloudFamily] = []; var offset = 0
            while true {
                let page: [CloudFamily] = try await client.from("families").select().order("id").range(from: offset, to: offset + 199).execute().value
                result += page
                if page.count < 200 { break }; offset += 200
            }
            guard generation == ticket else { return }
            let key = "care.family.\(userID)"
            if let last = defaults.string(forKey: key), let family = result.first(where: { $0.id.uuidString.caseInsensitiveCompare(last) == .orderedSame }) {
                await selectFamily(family.id)
            } else if let first = result.first {
                await selectFamily(first.id)
            } else {
                // A stable ID makes automatic setup retryable after network interruption.
                struct Params: Encodable { let p_id: UUID; let p_name: String }
                let id: UUID = try await client.rpc("babycare_create_family", params: Params(p_id: userID, p_name: "Hồ sơ của tôi")).execute().value
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
        viewModel = BabyCareViewModel(provider: provider, notifications: LocalCareReminderService(scope: "cloud.\(userID.uuidString).\(id.uuidString)"))
        defaults.set(id.uuidString, forKey: "care.family.\(userID)")
        phase = .content; busy = false
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
                if response.session == nil {
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
    func handleCallback(_ url: URL) async {
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
            try await CloudPrivacyDeletion.removeOwnedAccountMedia(client: client, userID: deletingUserID)
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
    private func authMessage(_ error: Error) -> String {
        if error is URLError { return L10n.text("Không kết nối được dịch vụ đăng nhập. Hãy kiểm tra mạng.") }
        return L10n.text("Chưa hoàn tất đăng nhập. Kiểm tra email, mật khẩu hoặc xác nhận email. Nếu gửi email thất bại, hãy thử lại sau hoặc kiểm tra cấu hình gửi email của project.")
    }
}
