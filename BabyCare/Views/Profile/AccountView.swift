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
            else if session.phase == .families { FamilySelectionView() }
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
    @State private var registering = false
    @State private var showingPassword = false
    @State private var resetting = false
    @State private var otp = ""
    @FocusState private var focus: Field?
    private enum Field { case email, password, otp }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        CareBrandView(size: 96)
                        Text(session.pendingSignupEmail != nil ? "Xác minh email" : resetting ? "Quên mật khẩu?" : registering ? "Tạo tài khoản" : "Đăng nhập")
                            .font(CareFont.largeTitle).accessibilityAddTraits(.isHeader)
                        Text(session.pendingSignupEmail.map { "Nhập mã 6 số đã gửi tới \($0)." }
                             ?? (resetting ? "Nhập email để nhận liên kết đặt lại mật khẩu."
                             : registering ? "Bắt đầu đồng hành cùng bé yêu."
                             : "Chào mừng bố mẹ quay trở lại với Bé Khỏe"))
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            .multilineTextAlignment(.center)
                    }.padding(.top, 24)

                    CareFormCard {
                        if session.pendingSignupEmail != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Mã xác minh", systemImage: "number.square").font(CareFont.subheadline.weight(.semibold))
                                TextField("000000", text: $otp)
                                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                                    .textFieldStyle(CareInputStyle()).focused($focus, equals: .otp)
                                    .accessibilityIdentifier("auth.otp")
                                    .onChange(of: otp) { _, value in otp = String(value.filter(\.isNumber).prefix(6)) }
                            }
                            Button {
                                focus = nil
                                Task { await session.verifySignupOTP(otp) }
                            } label: {
                                HStack {
                                    if session.busy { ProgressView().tint(.white) }
                                    Text("Xác minh và đăng nhập")
                                    Image(systemName: "checkmark.circle")
                                }
                            }.buttonStyle(CareActionStyle()).disabled(session.busy || otp.count != 6)
                                .accessibilityIdentifier("auth.verifyOTP")
                            Button("Gửi lại mã") { Task { await session.resendSignupOTP() } }
                                .frame(minHeight: 44).disabled(session.busy)
                            AccountFeedback()
                        } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Email", systemImage: "person").font(CareFont.subheadline.weight(.semibold))
                            TextField("Email", text: $email, prompt: Text(verbatim: "Ví dụ: bome@email.com"))
                                .textContentType(.username).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(CareInputStyle()).focused($focus, equals: .email)
                                .submitLabel(resetting ? .go : .next)
                                .accessibilityIdentifier("auth.email")
                                .onSubmit { if resetting { submit() } else { focus = .password } }
                        }
                        if !resetting {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Mật khẩu", systemImage: "lock").font(CareFont.subheadline.weight(.semibold))
                                HStack {
                                    Group {
                                        if showingPassword { TextField("Nhập mật khẩu", text: $password) }
                                        else { SecureField("Nhập mật khẩu", text: $password) }
                                    }
                                    .textContentType(registering ? .newPassword : .password)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focus, equals: .password).submitLabel(.go)
                                    .accessibilityIdentifier("auth.password").onSubmit(submit)
                                    Button { showingPassword.toggle() } label: {
                                        Image(systemName: showingPassword ? "eye" : "eye.slash")
                                            .frame(width: 44, height: 44)
                                    }.buttonStyle(.plain).foregroundStyle(CareTheme.secondary)
                                        .accessibilityLabel(showingPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                                }.padding(.leading, 14).padding(.trailing, 4)
                                    .frame(minHeight: 52)
                                    .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
                                if registering {
                                    Text("Tối thiểu 8 ký tự").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
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
                        Button(action: submit) {
                            HStack {
                                if session.busy { ProgressView().tint(.white) }
                                Text(resetting ? "Gửi liên kết đặt lại" : registering ? "Đăng ký & Bắt đầu" : "Đăng nhập")
                                Image(systemName: "arrow.right")
                            }
                        }.buttonStyle(CareActionStyle())
                            .disabled(session.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!resetting && password.isEmpty))
                            .accessibilityIdentifier("auth.submit")
                        AccountFeedback()
                        }
                    }
                    if session.pendingSignupEmail != nil {
                        Button("Dùng email khác") { otp = ""; session.cancelSignupVerification() }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else if resetting {
                        Button("Quay lại đăng nhập") { resetting = false }
                            .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else {
                        Button {
                            registering.toggle(); password = ""; showingPassword = false
                        } label: {
                            VStack(spacing: 4) {
                                Text(registering ? "Đã có tài khoản?" : "Chưa có tài khoản?")
                                    .foregroundStyle(CareTheme.secondary)
                                Text(registering ? "Đăng nhập" : "Đăng ký ngay").bold().underline()
                                    .foregroundStyle(CareTheme.accent)
                            }
                        }.font(CareFont.subheadline).frame(minHeight: 44).accessibilityIdentifier("auth.toggle")
                    }
                    if session.pendingSignupEmail == nil && !resetting {
                        HStack { Rectangle().frame(height: 1); Text("hoặc").font(CareFont.footnote); Rectangle().frame(height: 1) }
                            .foregroundStyle(CareTheme.border)
                        Button {
                            focus = nil
                            Task { await session.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                Text("Tiếp tục với Google").font(CareFont.body.weight(.semibold))
                            }.frame(maxWidth: .infinity).frame(minHeight: 50)
                                .background(CareTheme.surface, in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
                        }.buttonStyle(.plain).disabled(session.busy).accessibilityIdentifier("auth.google")
                    }
                    Button("Tiếp tục với dữ liệu trên máy") { Task { await session.openDevice() } }
                        .font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 48).disabled(session.busy)
                    Label("Hồ sơ và nhật ký được lưu theo tài khoản của bạn. Dữ liệu trên máy chỉ được tải lên khi bạn chủ động nhập.",
                          systemImage: "checkmark.shield")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareTheme.feedingBackground, in: .rect(cornerRadius: 14))
                }.padding(.horizontal, 20).padding(.bottom, 24).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen().scrollDismissesKeyboard(.interactively)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
    private func submit() {
        guard !session.busy, !email.isEmpty, resetting || !password.isEmpty else { return }
        focus = nil
        let value = password
        let action: SessionViewModel.AuthAction = resetting ? .resetPassword : registering ? .signUp : .signIn
        Task { await session.authenticate(action, email: email, password: value); password = "" }
    }
}

private struct FamilySelectionView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var name = "Gia đình của bé"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CareBrandView(size: 80)
                    CareSectionTitle(title: "Gia đình của bạn", subtitle: session.email)
                    CareFormCard {
                        ForEach(session.families) { family in
                            Button { Task { await session.selectFamily(family.id) } } label: {
                                Label(family.name, systemImage: "house").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            }
                        }
                        Button("Tải lại danh sách") { Task { await session.loadFamilies() } }
                    }
                    CareFormCard(title: "Tạo gia đình mới") {
                        TextField("Tên gia đình", text: $name).textFieldStyle(CareInputStyle())
                        CarePrimaryButton(title: "Tạo gia đình") { Task { await session.createFamily(name: name) } }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    AccountFeedback()
                    Button("Đăng xuất", role: .destructive) { Task { await session.signOut() } }.frame(minHeight: 48)
                }.padding(20).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.careScreen().disabled(session.busy).navigationBarTitleDisplayMode(.inline)
        }
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
            Section("Tài khoản & Gia đình") {
                Label(session.isLocal ? "Đang dùng dữ liệu trên máy" : session.email, systemImage: "person.crop.circle")
                    .font(CareFont.subheadline)
                if session.isLocal {
                    Button("Đăng nhập để lưu trên cloud") { Task { await session.openCloud() } }
                } else {
                    Button("Chọn gia đình") { Task { await session.chooseFamily() } }
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
