import Foundation
import Observation
import Supabase
import UserNotifications

@MainActor @Observable final class SessionViewModel {
    enum Phase { case starting, signedOut, accountError, content }
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
    @ObservationIgnored private var userID: UUID?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard
    static let callback = URL(string: "babycare://auth-callback")!
    private static let pendingSignupKey = "care.auth.pendingSignupEmail"

    init() {
        pendingSignupEmail = UserDefaults.standard.string(forKey: Self.pendingSignupKey)
    }

    func start(events suppliedEvents: AsyncStream<(event: AuthChangeEvent, session: Session?)>? = nil) {
        guard listener == nil else { return }
        let events = suppliedEvents ?? client.auth.authStateChanges
        listener = Task { [weak self] in
            for await (event, session) in events {
                guard !Task.isCancelled, let self else { return }
                if event == .passwordRecovery { needsNewPassword = true }
                if event == .initialSession, defaults.string(forKey: "care.mode") == "device" {
                    await openDevice(); continue
                }
                if isLocal { continue }
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
        isLocal = true; userID = nil; email = ""; busy = false
        defaults.set("device", forKey: "care.mode")
        viewModel = AppDependencies.makeViewModel(); phase = .content
    }
    func openCloud() async {
        let ticket = await detach(); guard generation == ticket else { return }
        isLocal = false; userID = nil
        defaults.set("cloud", forKey: "care.mode")
        await accept(client.auth.currentSession)
    }
    private func accept(_ session: Session?) async {
        let ticket = await detach(); guard generation == ticket else { return }
        userID = session?.user.id; email = session?.user.email ?? ""
        error = nil
        guard session != nil else { phase = .signedOut; return }
        pendingSignupEmail = nil
        defaults.removeObject(forKey: Self.pendingSignupKey)
        // Keep the splash visible while the previous family is restored. Publishing
        // `.accountError` here makes the family picker flash on every app launch.
        phase = .starting
        await loadAccount()
    }
    func loadAccount() async {
        guard let userID else { return }
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
        let ticket = await detach(); guard generation == ticket else { return }
        let remote = SupabaseRemote(authClient: client, userID: userID, familyID: id)
        let provider = SupabaseCareDataProvider(remote: remote, cache: SwiftDataCloudCache(userID: userID, familyID: id), familyID: id)
        viewModel = BabyCareViewModel(provider: provider, notifications: LocalCareReminderService())
        defaults.set(id.uuidString, forKey: "care.family.\(userID)")
        phase = .content; busy = false
    }
    enum AuthAction { case signIn, signUp, resetPassword }
    func authenticate(_ action: AuthAction, email: String, password: String, confirmation: String = "", captchaToken: String? = nil) async {
        guard !busy else { return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), !email.contains(" ") else { error = "Nhập email hợp lệ."; return }
        if case .signUp = action {
            if let validation = AuthValidation.signupError(password: password, confirmation: confirmation) { error = validation; return }
            guard !AuthCaptchaConfiguration.isEnabled || AuthCaptchaConfiguration.pageURL != nil else { error = "Đăng ký chưa khả dụng: cần cấu hình xác minh chống spam."; return }
        }
        if AuthCaptchaConfiguration.isEnabled && (captchaToken?.isEmpty ?? true) {
            error = "Vui lòng hoàn tất xác minh chống spam."; return
        }
        do {
            switch action {
            case .signIn:
                _ = try await client.auth.signIn(email: email, password: password, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
            case .signUp:
                guard password.count >= 8 else { error = "Mật khẩu cần ít nhất 8 ký tự."; return }
                let response = try await client.auth.signUp(email: email, password: password, redirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
                if response.session == nil {
                    pendingSignupEmail = email
                    defaults.set(email, forKey: Self.pendingSignupKey)
                    message = "Đã gửi email tới \(email). Bấm liên kết trong email để xác minh tài khoản."
                }
            case .resetPassword:
                try await client.auth.resetPasswordForEmail(email, redirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
                message = "Nếu tài khoản tồn tại, bạn sẽ nhận được email đặt lại mật khẩu."
            }
        } catch { self.error = authMessage(error) }
    }
    func resendSignupConfirmation(captchaToken: String? = nil) async {
        guard !busy, let email = pendingSignupEmail else { return }
        guard !AuthCaptchaConfiguration.isEnabled || !(captchaToken?.isEmpty ?? true) else { error = "Vui lòng hoàn tất xác minh chống spam."; return }
        busy = true; error = nil; message = nil
        defer { busy = false }
        do {
            try await client.auth.resend(email: email, type: .signup, emailRedirectTo: Self.callback, captchaToken: AuthCaptchaConfiguration.isEnabled ? captchaToken : nil)
            message = "Đã gửi lại email xác thực tới \(email)."
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
            self.error = "Không thể đăng nhập bằng Google. Hãy thử lại hoặc dùng email và mật khẩu."
        }
    }
    func handleCallback(_ url: URL) async {
        guard url.scheme == "babycare", url.host == "auth-callback" else { return }
        do { _ = try await client.auth.session(from: url) }
        catch { self.error = "Liên kết không còn hiệu lực. Hãy yêu cầu email mới." }
    }
    func updatePassword(_ password: String) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        guard password.count >= 8 else { error = "Mật khẩu cần ít nhất 8 ký tự."; return }
        do { _ = try await client.auth.update(user: UserAttributes(password: password)); needsNewPassword = false; message = "Đã đổi mật khẩu." }
        catch { self.error = authMessage(error) }
    }
    func signOut() async {
        let ticket = await detach(); guard generation == ticket else { return }
        userID = nil; email = ""; isLocal = false; phase = .signedOut
        needsNewPassword = false; pendingSignupEmail = nil; defaults.removeObject(forKey: Self.pendingSignupKey)
        error = nil; busy = true
        defaults.set("cloud", forKey: "care.mode")
        defer { busy = false }
        do { try await client.auth.signOut(scope: .local) }
        catch { message = "Đã thoát trên thiết bị. Chưa liên hệ được server để thu hồi phiên từ xa." }
    }
    private func authMessage(_ error: Error) -> String {
        if error is URLError { return "Không kết nối được dịch vụ đăng nhập. Hãy kiểm tra mạng." }
        return "Chưa hoàn tất đăng nhập. Kiểm tra email, mật khẩu hoặc xác nhận email. Nếu gửi email thất bại, hãy thử lại sau hoặc kiểm tra cấu hình gửi email của project."
    }
}
