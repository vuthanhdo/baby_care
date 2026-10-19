import AuthenticationServices
import SwiftUI

struct AppRootView: View {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.current.rawValue
    @State private var session: SessionViewModel
    @State private var testingModel: BabyCareViewModel?
    @Environment(\.scenePhase) private var scenePhase
    init() {
        #if DEBUG
        _session = State(initialValue: ConsentUITestFixture.enabled ? ConsentUITestFixture.makeSession() : SessionViewModel())
        #else
        _session = State(initialValue: SessionViewModel())
        #endif
    }
    private var bypass: Bool {
        #if DEBUG
        CareDemoMode.isActive || ProcessInfo.processInfo.arguments.contains { ["-ui-testing", "-ui-testing-store"].contains($0) }
        #else
        false
        #endif
    }
    private var authPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ui-testing-auth")
        #else
        false
        #endif
    }
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Group {
            if authPreview { SignInView() }
            else if bypass {
                if let testingModel { ContentView().environment(testingModel) }
                else { CareSplashView().task { testingModel = AppDependencies.makeViewModel() } }
            } else if session.needsNewPassword {
                NewPasswordView()
            } else if session.phase == .consent {
                OnboardingConsentView(model: session.consent,
                    onAccept: { await session.completeConsent() }, onBack: { await session.signOut() },
                    onRetry: { await session.checkConsent() })
            } else if let model = session.viewModel, session.phase == .content {
                ContentView().environment(model).id(ObjectIdentifier(model))
            } else if session.phase == .starting { CareSplashView() }
            else if session.phase == .accountError { AccountLoadingErrorView() }
            else { SignInView() }
        }
        .environment(\.locale, (AppLanguage(rawValue: language) ?? .english).locale)
        .environment(session)
        .font(CareFont.body)
        .foregroundStyle(CareTheme.text)
        .preferredColorScheme(.light)
        .task {
            #if DEBUG
            if ConsentUITestFixture.enabled { session.start(events: ConsentUITestFixture.events()); return }
            #endif
            if !bypass && !authPreview { session.start() }
        }
        .onOpenURL { url in Task { await session.handleCallback(url) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !bypass && !authPreview { Task { await session.checkConsent() } }
        }
        .onChange(of: session.viewModel?.state.requiresConsent) { _, required in
            if required == true { Task { await session.checkConsent() } }
        }
        .tint(CareTheme.accent)
    }
}

/// Stitch login/signup layout with email verification, Sign in with Apple and Google OAuth.
struct SignInView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var captchaToken: String?
    @State private var captchaID = UUID()
    @State private var registering = false
    @State private var googleLoading = false
    @State private var appleNonce = ""
    @State private var showingPassword = false
    @State private var resetting = false
    @State private var touched: Set<Field> = []
    @FocusState private var focus: Field?
    private enum Field { case email, password, confirmation }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack { Spacer(); LanguagePicker() }.disabled(session.busy)
                    if !registering || session.pendingSignupEmail != nil || resetting {
                        entryHeader
                        if session.pendingSignupEmail == nil && !resetting { appleButton; googleButton; emailDivider }
                    }
                    EntryFormCard {
                        if registering && session.pendingSignupEmail == nil && !resetting {
                            entryHeader
                            appleButton
                            googleButton
                            emailDivider
                        }
                        if session.pendingSignupEmail != nil {
                            Label(L10n.text("Kiểm tra hộp thư của bạn"), systemImage: "envelope.badge")
                                .font(CareFont.body.weight(.semibold))
                                .accessibilityIdentifier("auth.checkEmail")
                            Text(L10n.text("Bấm liên kết xác thực trong email để quay lại Bé Khỏe và hoàn tất đăng ký. Nếu chưa thấy email, hãy kiểm tra thư rác."))
                                .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            captchaSection
                            CareAsyncButton(L10n.text("Gửi lại email xác thực")) { await session.resendSignupConfirmation(captchaToken: captchaToken); resetCaptcha() }
                                .frame(minHeight: 44).disabled(session.busy)
                            AccountFeedback()
                        } else {
                        VStack(alignment: .leading, spacing: 8) {
                            EntryFieldLabel(title: "Email", icon: "person")
                            TextField("Email", text: $email, prompt: Text(verbatim: L10n.text("Ví dụ: bome@email.com")))
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(EntryInputStyle()).focused($focus, equals: .email)
                                .submitLabel(resetting ? .go : .next)
                                .accessibilityIdentifier("auth.email")
                                .onSubmit { if resetting { submit() } else { focus = .password } }
                            inlineError(AuthValidation.emailError(email), field: .email, value: email, id: "auth.emailError")
                        }
                        if !resetting {
                            VStack(alignment: .leading, spacing: 8) {
                                EntryFieldLabel(title: L10n.text("Mật khẩu"), icon: "lock")
                                HStack {
                                    Group {
                                        if showingPassword { TextField(L10n.text("Nhập mật khẩu"), text: $password) }
                                        else { SecureField(L10n.text("Nhập mật khẩu"), text: $password) }
                                    }
                                    .textContentType(registering ? .newPassword : .password)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focus, equals: .password).submitLabel(registering ? .next : .go)
                                    .accessibilityIdentifier("auth.password").onSubmit { if registering { focus = .confirmation } else { submit() } }
                                    Button { showingPassword.toggle() } label: {
                                        CareIcon(name: showingPassword ? "Stitch_visibility" : "Stitch_visibility_off", color: CareTheme.secondary, size: 20)
                                            .frame(width: 44, height: 44)
                                    }.buttonStyle(.plain).foregroundStyle(CareTheme.secondary)
                                        .accessibilityLabel(showingPassword ? L10n.text("Ẩn mật khẩu") : L10n.text("Hiện mật khẩu"))
                                }.padding(.leading, 14).padding(.trailing, 4)
                                    .frame(minHeight: 48)
                                    .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
                                inlineError(registering ? AuthValidation.passwordError(password) : (password.isEmpty ? L10n.text("Vui lòng nhập mật khẩu.") : nil), field: .password, value: password, id: "auth.passwordError")
                                if registering {
                                    Text(L10n.text("Ít nhất 8 ký tự, 1 chữ hoa và 1 ký tự đặc biệt")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                                }
                            }
                            if registering {
                                VStack(alignment: .leading, spacing: 8) {
                                    EntryFieldLabel(title: L10n.text("Nhập lại mật khẩu"), icon: "lock")
                                    SecureField(L10n.text("Nhập lại mật khẩu"), text: $confirmation)
                                        .textContentType(.newPassword).textInputAutocapitalization(.never).autocorrectionDisabled()
                                        .textFieldStyle(EntryInputStyle()).focused($focus, equals: .confirmation)
                                        .submitLabel(.go).onSubmit(submit).accessibilityIdentifier("auth.confirmPassword")
                                    inlineError(AuthValidation.confirmationError(password: password, confirmation: confirmation), field: .confirmation, value: confirmation, id: "auth.passwordMismatch")
                                }
                            }
                            if !registering {
                                HStack {
                                    Label(L10n.text("Lưu phiên đăng nhập"), systemImage: "checkmark.shield")
                                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                    Spacer(minLength: 8)
                                    Button(L10n.text("Quên mật khẩu?")) { resetting = true; touched = []; password = "" }
                                        .font(CareFont.footnote.weight(.semibold)).frame(minHeight: 44)
                                }
                            }
                        }
                        captchaSection
                        Button(action: submit) {
                            HStack {
                                if session.busy && !googleLoading { ProgressView().tint(.white) }
                                Text(resetting ? L10n.text("Gửi liên kết đặt lại") : registering ? L10n.text("Đăng ký & Bắt đầu") : L10n.text("Đăng nhập"))
                                CareIcon(name: "Stitch_arrow_forward", color: .white, size: 20)
                            }
                        }.buttonStyle(CareActionStyle())
                            .disabled(session.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!resetting && password.isEmpty))
                            .accessibilityIdentifier("auth.submit")
                        AccountFeedback()
                        }
                    }
                    if session.pendingSignupEmail != nil {
                        Button(L10n.text("Dùng email khác")) { session.cancelSignupVerification() }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                        Button(L10n.text("Đã xác minh? Đăng nhập")) { session.cancelSignupVerification(); registering = false; password = ""; confirmation = "" }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else if resetting {
                        Button(L10n.text("Quay lại đăng nhập")) { resetting = false }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else {
                        Button {
                            registering.toggle(); touched = []; password = ""; confirmation = ""; showingPassword = false; resetCaptcha()
                        } label: {
                            HStack(spacing: 4) {
                                Text(registering ? L10n.text("Đã có tài khoản?") : L10n.text("Chưa có tài khoản?"))
                                    .foregroundStyle(CareTheme.secondary)
                                Text(registering ? L10n.text("Đăng nhập") : L10n.text("Đăng ký ngay")).bold().underline()
                                    .foregroundStyle(CareTheme.accent)
                            }
                        }.font(CareFont.subheadline).frame(minHeight: 44).accessibilityIdentifier("auth.toggle")
                    }
                    CareAsyncButton(L10n.text("Tiếp tục với dữ liệu trên máy")) { await session.openDevice() }
                        .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 48).disabled(session.busy)
                    Label(L10n.text("Hồ sơ và nhật ký được lưu theo tài khoản của bạn. Dữ liệu trên máy chỉ được tải lên khi bạn chủ động nhập."),
                          systemImage: "checkmark.shield")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareTheme.feedingBackground, in: .rect(cornerRadius: 14))
                }.font(CareFont.subheadline).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen().scrollDismissesKeyboard(.interactively)
                .onChange(of: focus) { old, _ in if let old { touched.insert(old) } }
                .id(registering)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if registering {
                        HStack {
                            Button { registering = false; password = ""; confirmation = ""; resetCaptcha() } label: {
                                HStack(spacing: 2) {
                                    CareIcon(name: "Stitch_chevron_left", color: CareTheme.accent, size: 24)
                                    Text(L10n.text("Đăng nhập")).font(CareFont.subheadline).foregroundStyle(CareTheme.accent)
                                }
                            }.buttonStyle(.plain).frame(minHeight: 48)
                            Spacer()
                        }.padding(.horizontal, 20).background(CareTheme.background)
                            .overlay(alignment: .bottom) { Rectangle().fill(CareTheme.border).frame(height: 0.5) }
                    }
                }
        }
    }
    private var entryHeader: some View {
        VStack(alignment: registering ? .leading : .center, spacing: 8) {
            CareBrandView(size: registering ? 64 : 80)
            if registering && session.pendingSignupEmail == nil {
                HStack(spacing: 5) {
                    CareIcon(name: "Stitch_favorite", color: CareTheme.accent, size: 14)
                    Text(L10n.text("Bước đầu tiên")).font(CareFont.caption)
                }.padding(.horizontal, 10).padding(.vertical, 5)
                    .background(CareTheme.accent.opacity(0.07), in: .capsule)
            }
            Text(session.pendingSignupEmail != nil ? L10n.text("Xác minh email") : resetting ? L10n.text("Quên mật khẩu?") : registering ? L10n.text("Tạo tài khoản") : L10n.text("Đăng nhập"))
                .font(CareFont.title).accessibilityAddTraits(.isHeader)
            Text(session.pendingSignupEmail.map { L10n.text("Mở email gửi tới {0} và bấm liên kết để xác minh tài khoản.", "\($0)") }
                 ?? (resetting ? L10n.text("Nhập email để nhận liên kết đặt lại mật khẩu.") : registering ? L10n.text("Bắt đầu đồng hành cùng bé yêu.") : L10n.text("Chào mừng bố mẹ quay trở lại với Bé Khỏe")))
                .font(CareFont.callout).foregroundStyle(CareTheme.secondary)
                .multilineTextAlignment(registering ? .leading : .center)
        }.frame(maxWidth: .infinity, alignment: registering ? .leading : .center)
    }
    /// Apple's own button (required next to Google by App Store guideline 4.8); its label follows the device language.
    private var appleButton: some View {
        SignInWithAppleButton(registering ? .signUp : .continue) { request in
            focus = nil
            appleNonce = AppleSignInNonce.random()
            request.requestedScopes = [.email]
            request.nonce = AppleSignInNonce.sha256(appleNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { session.appleSignInFailed(); return }
                let nonce = appleNonce
                let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                Task { await session.signInWithApple(idToken: token, nonce: nonce, authorizationCode: code) }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                session.appleSignInFailed()
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity).frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(session.busy)
        .accessibilityIdentifier("auth.apple")
    }
    private var googleButton: some View {
        Button {
            focus = nil
            googleLoading = true
            Task { defer { googleLoading = false }; await session.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                if googleLoading { ProgressView() }
                else { Image("GoogleSignInMark").resizable().scaledToFit().frame(width: 20, height: 20) }
                Text(registering ? L10n.text("Đăng ký nhanh với Google") : L10n.text("Tiếp tục với Google"))
                    .font(CareFont.subheadline.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 48)
                .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
        }.buttonStyle(.plain).disabled(session.busy).accessibilityIdentifier("auth.google")
    }
    private var emailDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(CareTheme.border).frame(height: 1)
            Text(registering ? L10n.text("Hoặc điền thông tin bên dưới") : L10n.text("hoặc đăng nhập bằng email"))
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Rectangle().fill(CareTheme.border).frame(height: 1)
        }
    }
    @ViewBuilder private var captchaSection: some View {
        if AuthCaptchaConfiguration.isEnabled, let url = AuthCaptchaConfiguration.pageURL {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Xác minh bảo mật")).font(CareFont.subheadline.weight(.semibold))
                AuthCaptchaView(url: url, token: $captchaToken).id(captchaID).frame(height: 150)
                Button(L10n.text("Tải lại xác minh")) { resetCaptcha() }.font(CareFont.footnote).disabled(session.busy)
            }
        } else if registering && AuthCaptchaConfiguration.isEnabled {
            Text(L10n.text("Xác minh chống spam chưa được cấu hình. Vui lòng thử đăng ký sau."))
                .font(CareFont.footnote).foregroundStyle(CareTheme.medical)
        }
    }
    @ViewBuilder private func inlineError(_ error: String?, field: Field, value: String, id: String) -> some View {
        if let error, !value.isEmpty || touched.contains(field) {
            Text(error).font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                .accessibilityIdentifier(id)
        }
    }
    private func resetCaptcha() { captchaToken = nil; captchaID = UUID() }
    private func submit() {
        guard !session.busy, !email.isEmpty, resetting || !password.isEmpty else { return }
        touched = [.email, .password, .confirmation]
        guard AuthValidation.emailError(email) == nil else { return }
        if registering && !resetting {
            guard AuthValidation.signupError(password: password, confirmation: confirmation) == nil else { return }
        }
        focus = nil
        let value = password
        let action: SessionViewModel.AuthAction = resetting ? .resetPassword : registering ? .signUp : .signIn
        Task { await session.authenticate(action, email: email, password: value, confirmation: confirmation, captchaToken: captchaToken); resetCaptcha()
            if session.pendingSignupEmail != nil { password = ""; confirmation = "" }
        }
    }
}

/// Recovery screen shown only when account data cannot be loaded.
private struct AccountLoadingErrorView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(spacing: 20) {
            CareBrandView()
            Text(L10n.text("Chưa tải được hồ sơ của bạn")).font(CareFont.title)
            AccountFeedback()
            CarePrimaryButton(title: L10n.text("Thử lại"), isLoading: session.busy) { Task { await session.loadAccount() } }
            CareAsyncButton(L10n.text("Đăng xuất")) { await session.signOut() }
        }.padding(24).disabled(session.busy)
    }
}

private struct NewPasswordView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var password = ""
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CareBrandView()
                    Text(L10n.text("Đặt lại mật khẩu")).font(CareFont.largeTitle)
                    CareFormCard {
                        SecureField(L10n.text("Mật khẩu mới"), text: $password)
                            .textContentType(.newPassword).textFieldStyle(CareInputStyle())
                        Text(L10n.text("Ít nhất 8 ký tự, 1 chữ hoa và 1 ký tự đặc biệt")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        if !password.isEmpty, let error = AuthValidation.passwordError(password) {
                            Text(error).font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                        }
                        CarePrimaryButton(title: L10n.text("Lưu mật khẩu mới"), isLoading: session.busy) {
                            Task { await session.updatePassword(password); password = "" }
                        }.disabled(session.busy || AuthValidation.passwordError(password) != nil)
                        AccountFeedback()
                    }
                    CareAsyncButton(L10n.text("Đăng xuất")) { await session.signOut() }
                }.padding(20).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen()
        }
    }
}

/// Account controls live in Settings so the baby header stays focused on the selected child.
struct CareAccountSection: View {
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        if let session, session.phase == .content {
            Section(L10n.text("Tài khoản")) {
                Label(session.isLocal ? L10n.text("Đang dùng dữ liệu trên máy") : session.email, systemImage: "person.crop.circle")
                    .font(CareFont.subheadline)
                if session.isLocal {
                    CareAsyncButton(L10n.text("Đăng nhập để lưu trên cloud")) { await session.openCloud() }
                } else {
                    CareAsyncButton(L10n.text("Đăng xuất"), role: .destructive) { await session.signOut() }
                }
            }.disabled(session.busy)
        }
    }
}

private struct AccountFeedback: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        if let error = session.error {
            Label(error, systemImage: "exclamationmark.circle")
                .font(CareFont.footnote).foregroundStyle(CareTheme.medical).accessibilityIdentifier("account.error")
        }
        if let message = session.message {
            Label(message, systemImage: "envelope").font(CareFont.footnote).foregroundStyle(CareTheme.accent)
        }
    }
}
