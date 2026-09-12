import SwiftUI

struct AppRootView: View {
    @State private var session = SessionViewModel()
    @State private var testingModel: BabyCareViewModel?
    private var bypass: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { ["-demo", "-ui-testing", "-ui-testing-store"].contains($0) }
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
    var body: some View {
        Group {
            if authPreview { SignInView() }
            else if bypass {
                if let testingModel { ContentView().environment(testingModel) }
                else { CareSplashView().task { testingModel = AppDependencies.makeViewModel() } }
            } else if session.needsNewPassword {
                NewPasswordView()
            } else if let model = session.viewModel, session.phase == .content {
                ContentView().environment(model).id(ObjectIdentifier(model))
            } else if session.phase == .starting { CareSplashView() }
            else if session.phase == .accountError { AccountLoadingErrorView() }
            else { SignInView() }
        }
        .environment(session)
        .font(CareFont.body)
        .foregroundStyle(CareTheme.text)
        .preferredColorScheme(.light)
        .task { if !bypass && !authPreview { session.start() } }
        .onOpenURL { url in Task { await session.handleCallback(url) } }
        .tint(CareTheme.accent)
    }
}

/// Stitch login/signup layout with email verification and Google OAuth.
struct SignInView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var captchaToken: String?
    @State private var captchaID = UUID()
    @State private var registering = false
    @State private var showingPassword = false
    @State private var resetting = false
    @FocusState private var focus: Field?
    private enum Field { case email, password, confirmation }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !registering || session.pendingSignupEmail != nil || resetting {
                        entryHeader
                        if session.pendingSignupEmail == nil && !resetting { googleButton; emailDivider }
                    }
                    EntryFormCard {
                        if registering && session.pendingSignupEmail == nil && !resetting {
                            entryHeader
                            googleButton
                            emailDivider
                        }
                        if session.pendingSignupEmail != nil {
                            Label("Kiểm tra hộp thư của bạn", systemImage: "envelope.badge")
                                .font(CareFont.body.weight(.semibold))
                                .accessibilityIdentifier("auth.checkEmail")
                            Text("Bấm liên kết xác thực trong email để quay lại Bé Khỏe và hoàn tất đăng ký. Nếu chưa thấy email, hãy kiểm tra thư rác.")
                                .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            captchaSection
                            Button("Gửi lại email xác thực") { Task { await session.resendSignupConfirmation(captchaToken: captchaToken); resetCaptcha() } }
                                .frame(minHeight: 44).disabled(session.busy)
                            AccountFeedback()
                        } else {
                        VStack(alignment: .leading, spacing: 8) {
                            EntryFieldLabel(title: "Email", icon: "person")
                            TextField("Email", text: $email, prompt: Text(verbatim: "Ví dụ: bome@email.com"))
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(EntryInputStyle()).focused($focus, equals: .email)
                                .submitLabel(resetting ? .go : .next)
                                .accessibilityIdentifier("auth.email")
                                .onSubmit { if resetting { submit() } else { focus = .password } }
                        }
                        if !resetting {
                            VStack(alignment: .leading, spacing: 8) {
                                EntryFieldLabel(title: "Mật khẩu", icon: "lock")
                                HStack {
                                    Group {
                                        if showingPassword { TextField("Nhập mật khẩu", text: $password) }
                                        else { SecureField("Nhập mật khẩu", text: $password) }
                                    }
                                    .textContentType(registering ? .newPassword : .password)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focus, equals: .password).submitLabel(registering ? .next : .go)
                                    .accessibilityIdentifier("auth.password").onSubmit { if registering { focus = .confirmation } else { submit() } }
                                    Button { showingPassword.toggle() } label: {
                                        CareIcon(name: showingPassword ? "Stitch_visibility" : "Stitch_visibility_off", color: CareTheme.secondary, size: 20)
                                            .frame(width: 44, height: 44)
                                    }.buttonStyle(.plain).foregroundStyle(CareTheme.secondary)
                                        .accessibilityLabel(showingPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                                }.padding(.leading, 14).padding(.trailing, 4)
                                    .frame(minHeight: 48)
                                    .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
                                if registering {
                                    Text("Tối thiểu 8 ký tự").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                                }
                            }
                            if registering {
                                VStack(alignment: .leading, spacing: 8) {
                                    EntryFieldLabel(title: "Nhập lại mật khẩu", icon: "lock")
                                    SecureField("Nhập lại mật khẩu", text: $confirmation)
                                        .textContentType(.newPassword).textInputAutocapitalization(.never).autocorrectionDisabled()
                                        .textFieldStyle(EntryInputStyle()).focused($focus, equals: .confirmation)
                                        .submitLabel(.go).onSubmit(submit).accessibilityIdentifier("auth.confirmPassword")
                                    if !confirmation.isEmpty && password != confirmation {
                                        Text("Mật khẩu nhập lại không khớp.").font(CareFont.footnote)
                                            .foregroundStyle(CareTheme.medical).accessibilityIdentifier("auth.passwordMismatch")
                                    }
                                }
                            }
                            if !registering {
                                HStack {
                                    Label("Lưu phiên đăng nhập", systemImage: "checkmark.shield")
                                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                    Spacer(minLength: 8)
                                    Button("Quên mật khẩu?") { resetting = true; password = "" }
                                        .font(CareFont.footnote.weight(.semibold)).frame(minHeight: 44)
                                }
                            }
                        }
                        captchaSection
                        Button(action: submit) {
                            HStack {
                                if session.busy { ProgressView().tint(.white) }
                                Text(resetting ? "Gửi liên kết đặt lại" : registering ? "Đăng ký & Bắt đầu" : "Đăng nhập")
                                CareIcon(name: "Stitch_arrow_forward", color: .white, size: 20)
                            }
                        }.buttonStyle(CareActionStyle())
                            .disabled(session.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!resetting && password.isEmpty))
                            .accessibilityIdentifier("auth.submit")
                        AccountFeedback()
                        }
                    }
                    if session.pendingSignupEmail != nil {
                        Button("Dùng email khác") { session.cancelSignupVerification() }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                        Button("Đã xác minh? Đăng nhập") { session.cancelSignupVerification(); registering = false; password = ""; confirmation = "" }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else if resetting {
                        Button("Quay lại đăng nhập") { resetting = false }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else {
                        Button {
                            registering.toggle(); password = ""; confirmation = ""; showingPassword = false; resetCaptcha()
                        } label: {
                            HStack(spacing: 4) {
                                Text(registering ? "Đã có tài khoản?" : "Chưa có tài khoản?")
                                    .foregroundStyle(CareTheme.secondary)
                                Text(registering ? "Đăng nhập" : "Đăng ký ngay").bold().underline()
                                    .foregroundStyle(CareTheme.accent)
                            }
                        }.font(CareFont.subheadline).frame(minHeight: 44).accessibilityIdentifier("auth.toggle")
                    }
                    Button("Tiếp tục với dữ liệu trên máy") { Task { await session.openDevice() } }
                        .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 48).disabled(session.busy)
                    Label("Hồ sơ và nhật ký được lưu theo tài khoản của bạn. Dữ liệu trên máy chỉ được tải lên khi bạn chủ động nhập.",
                          systemImage: "checkmark.shield")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareTheme.feedingBackground, in: .rect(cornerRadius: 14))
                }.font(CareFont.subheadline).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen().scrollDismissesKeyboard(.interactively)
                .id(registering)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if registering {
                        HStack {
                            Button { registering = false; password = ""; confirmation = ""; resetCaptcha() } label: {
                                HStack(spacing: 2) {
                                    CareIcon(name: "Stitch_chevron_left", color: CareTheme.accent, size: 24)
                                    Text("Đăng nhập").font(CareFont.subheadline).foregroundStyle(CareTheme.accent)
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
                    Text("Bước đầu tiên").font(CareFont.caption)
                }.padding(.horizontal, 10).padding(.vertical, 5)
                    .background(CareTheme.accent.opacity(0.07), in: .capsule)
            }
            Text(session.pendingSignupEmail != nil ? "Xác minh email" : resetting ? "Quên mật khẩu?" : registering ? "Tạo tài khoản" : "Đăng nhập")
                .font(CareFont.title).accessibilityAddTraits(.isHeader)
            Text(session.pendingSignupEmail.map { "Mở email gửi tới \($0) và bấm liên kết để xác minh tài khoản." }
                 ?? (resetting ? "Nhập email để nhận liên kết đặt lại mật khẩu." : registering ? "Bắt đầu đồng hành cùng bé yêu." : "Chào mừng bố mẹ quay trở lại với Bé Khỏe"))
                .font(CareFont.callout).foregroundStyle(CareTheme.secondary)
                .multilineTextAlignment(registering ? .leading : .center)
        }.frame(maxWidth: .infinity, alignment: registering ? .leading : .center)
    }
    private var googleButton: some View {
        Button {
            focus = nil
            Task { await session.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleSignInMark").resizable().scaledToFit().frame(width: 20, height: 20)
                Text(registering ? "Đăng ký nhanh với Google" : "Tiếp tục với Google")
                    .font(CareFont.subheadline.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 48)
                .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
        }.buttonStyle(.plain).disabled(session.busy).accessibilityIdentifier("auth.google")
    }
    private var emailDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(CareTheme.border).frame(height: 1)
            Text(registering ? "Hoặc điền thông tin bên dưới" : "hoặc đăng nhập bằng email")
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Rectangle().fill(CareTheme.border).frame(height: 1)
        }
    }
    @ViewBuilder private var captchaSection: some View {
        if AuthCaptchaConfiguration.isEnabled, let url = AuthCaptchaConfiguration.pageURL {
            VStack(alignment: .leading, spacing: 8) {
                Text("Xác minh bảo mật").font(CareFont.subheadline.weight(.semibold))
                AuthCaptchaView(url: url, token: $captchaToken).id(captchaID).frame(height: 150)
                Button("Tải lại xác minh") { resetCaptcha() }.font(CareFont.footnote).disabled(session.busy)
            }
        } else if registering && AuthCaptchaConfiguration.isEnabled {
            Text("Xác minh chống spam chưa được cấu hình. Vui lòng thử đăng ký sau.")
                .font(CareFont.footnote).foregroundStyle(CareTheme.medical)
        }
    }
    private func resetCaptcha() { captchaToken = nil; captchaID = UUID() }
    private func submit() {
        guard !session.busy, !email.isEmpty, resetting || !password.isEmpty else { return }
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
    var body: some View {
        VStack(spacing: 20) {
            CareBrandView()
            Text("Chưa tải được hồ sơ của bạn").font(CareFont.title)
            AccountFeedback()
            CarePrimaryButton(title: "Thử lại") { Task { await session.loadAccount() } }
            Button("Đăng xuất") { Task { await session.signOut() } }
        }.padding(24).disabled(session.busy)
    }
}

private struct NewPasswordView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var password = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CareBrandView()
                    Text("Đặt lại mật khẩu").font(CareFont.largeTitle)
                    CareFormCard {
                        SecureField("Mật khẩu mới, tối thiểu 8 ký tự", text: $password)
                            .textContentType(.newPassword).textFieldStyle(CareInputStyle())
                        CarePrimaryButton(title: "Lưu mật khẩu mới") {
                            Task { await session.updatePassword(password); password = "" }
                        }.disabled(session.busy || password.count < 8)
                        AccountFeedback()
                    }
                    Button("Đăng xuất") { Task { await session.signOut() } }
                }.padding(20).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen()
        }
    }
}

/// Account controls live in Settings so the baby header stays focused on the selected child.
struct CareAccountSection: View {
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    var body: some View {
        if let session, session.phase == .content {
            Section("Tài khoản") {
                Label(session.isLocal ? "Đang dùng dữ liệu trên máy" : session.email, systemImage: "person.crop.circle")
                    .font(CareFont.subheadline)
                if session.isLocal {
                    Button("Đăng nhập để lưu trên cloud") { Task { await session.openCloud() } }
                } else {
                    Button("Đăng xuất", role: .destructive) { Task { await session.signOut() } }
                }
            }.disabled(session.busy)
        }
    }
}

private struct AccountFeedback: View {
    @Environment(SessionViewModel.self) private var session
    var body: some View {
        if let error = session.error {
            Label(error, systemImage: "exclamationmark.circle")
                .font(CareFont.footnote).foregroundStyle(CareTheme.medical).accessibilityIdentifier("account.error")
        }
        if let message = session.message {
            Label(message, systemImage: "envelope").font(CareFont.footnote).foregroundStyle(CareTheme.accent)
        }
    }
}
