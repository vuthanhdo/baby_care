import PhotosUI
import SwiftUI

/// The "Góp ý" tab: send a message to the developer, or vote on the feature board.
struct FeedbackView: View {
    static let supportEmail = "thanhdo.vtb@gmail.com"
    enum Mode: Hashable { case message, features }
    @State private var mode: Mode = .message
    @Environment(\.locale) private var appLocale

    var body: some View {
        let _ = appLocale
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("Góp ý cho Bé Khỏe")).font(CareFont.title.bold()).foregroundStyle(CareTheme.text)
                Picker(L10n.text("Mục"), selection: $mode) {
                    Text(L10n.text("Gửi góp ý")).tag(Mode.message)
                    Text(L10n.text("Bình chọn tính năng")).tag(Mode.features)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("feedback.mode")
                Text(mode == .message ? L10n.text("Gửi lỗi kèm ảnh chụp, góp ý hoặc câu hỏi thẳng tới nhà phát triển.")
                                      : L10n.text("Bình chọn tính năng bạn muốn có. Đề xuất nhiều phiếu được ưu tiên làm trước."))
                    .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
            switch mode {
            case .message: FeedbackForm()
            case .features: FeatureBoardView()
            }
        }
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(CareTheme.background)
        // A tab root like Quick log: the baby header (with Settings) on top.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // each tab root hides the system bar; the app draws its own tabs
        .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
    }
}

/// A bug with screenshots, a suggestion or another message, stored in `app_feedback` for the developer
/// (migration 0013). The draft keeps its id, so sending again after an error never duplicates it.
struct FeedbackForm: View {
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var draft = CareFeedbackDraft()
    @State private var picked: [PhotosPickerItem] = []
    @State private var loadingImages = false
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?
    @Environment(\.locale) private var appLocale

    private var context: CareFeedbackContext { .current(storage: viewModel.state.storage == .device ? "device" : "cloud") }
    private var email: String { session?.email ?? "" }

    var body: some View {
        let _ = appLocale
        Group {
            if sent { thanks } else { form }
        }
    }

    private var form: some View {
        List {
            Section {
                Picker(L10n.text("Loại"), selection: $draft.kind) {
                    ForEach(CareFeedbackKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                .accessibilityIdentifier("feedback.kind")
            }
            Section {
                TextEditor(text: $draft.message)
                    .frame(minHeight: 150)
                    .overlay(alignment: .topLeading) {
                        if draft.message.isEmpty {
                            Text(draft.kind.prompt).foregroundStyle(CareTheme.secondary).padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityIdentifier("feedback.message")
            } header: { Text(L10n.text("Nội dung")) } footer: {
                // Verbatim: an interpolated Int is grouped by locale ("4.000" in Vietnamese).
                Text(verbatim: "\(draft.trimmedMessage.count)/\(CareFeedbackDraft.maximumLength)")
                    .foregroundStyle(draft.trimmedMessage.count > CareFeedbackDraft.maximumLength ? CareTheme.medical : CareTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Section {
                if !draft.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(draft.images.enumerated()), id: \.offset) { index, data in thumbnail(data, index: index) }
                        }.padding(.vertical, 4)
                    }
                }
                if draft.images.count < CareFeedbackDraft.maximumImages {
                    PhotosPicker(selection: $picked, maxSelectionCount: CareFeedbackDraft.maximumImages - draft.images.count, matching: .images) {
                        Label {
                            Text(loadingImages ? L10n.text("Đang xử lý ảnh…") : L10n.text("Thêm ảnh chụp màn hình"))
                        } icon: { CareIcon(name: "Stitch_add_a_photo", color: CareTheme.accent, size: 20) }
                    }
                    .disabled(loadingImages)
                    .accessibilityIdentifier("feedback.addImage")
                }
            } header: { Text(L10n.text("Ảnh đính kèm · tối đa {0}", "\(CareFeedbackDraft.maximumImages)")) } footer: {
                Text(L10n.text("Ảnh chụp màn hình giúp tìm lỗi nhanh hơn. Hãy bỏ những ảnh có thông tin bạn không muốn gửi."))
            }
            if !email.isEmpty {
                Section {
                    Toggle(isOn: $draft.allowContact) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("Cho phép liên hệ lại qua email"))
                            Text(email).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                    }.accessibilityIdentifier("feedback.allowContact")
                }
            }
            Section {
                Text(L10n.text("Gửi kèm thông tin kỹ thuật để dễ tìm lỗi: {0}. Dữ liệu của bé không được gửi, trừ khi có trong ảnh bạn chọn.", context.summary))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }
            if session?.canSendFeedback != true {
                Section {
                    Text(L10n.text("Hãy đăng nhập để gửi góp ý trong app, hoặc gửi email cho nhà phát triển."))
                    Link(FeedbackView.supportEmail, destination: URL(string: "mailto:\(FeedbackView.supportEmail)")!)
                }
            }
        }
        .font(CareFont.subheadline)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // Next to the button, not at the end of the list where it would sit below the fold.
                if let error {
                    Label(error, systemImage: "exclamationmark.circle").font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("feedback.error")
                }
                CarePrimaryButton(title: L10n.text("Gửi"), icon: "Stitch_contact_mail", isLoading: sending) { Task { await send() } }
                    .disabled(!draft.canSend || loadingImages || session?.canSendFeedback != true)
                    .accessibilityIdentifier("feedback.send")
            }
            .padding(.horizontal, 20).padding(.vertical, 12).background(CareTheme.background)
        }
        .task(id: picked) { await loadPicked() }
    }

    private func thumbnail(_ data: Data, index: Int) -> some View {
        #if canImport(UIKit)
        let image = UIImage(data: data).map(Image.init(uiImage:)) ?? Image(systemName: "photo")
        #else
        let image = Image(systemName: "photo")
        #endif
        return image.resizable().scaledToFill().frame(width: 84, height: 112).clipShape(.rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CareTheme.border))
            .overlay(alignment: .topTrailing) {
                Button { draft.images.remove(at: index) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }.buttonStyle(.plain).padding(4).accessibilityLabel(L10n.text("Bỏ ảnh {0}", "\(index + 1)"))
            }
    }

    private var thanks: some View {
        VStack(spacing: 16) {
            Spacer()
            CareIcon(name: "Stitch_task_alt", color: CareTheme.accent, size: 40)
                .frame(width: 80, height: 80).background(CareTheme.accent.opacity(0.1), in: .circle)
            Text(L10n.text("Cảm ơn bạn!")).font(CareFont.title2.bold())
            Text(draft.allowContact && !email.isEmpty
                 ? L10n.text("Góp ý đã được gửi tới nhà phát triển. Nếu cần thêm thông tin, chúng tôi sẽ liên hệ qua {0}.", email)
                 : L10n.text("Góp ý đã được gửi tới nhà phát triển."))
                .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
            Spacer()
            // The tab stays: a fresh form for the next message.
            CarePrimaryButton(title: L10n.text("Gửi góp ý khác")) { draft = CareFeedbackDraft(); error = nil; sent = false }
                .accessibilityIdentifier("feedback.done")
        }
        .padding(24)
    }

    private func loadPicked() async {
        let items = picked
        guard !items.isEmpty else { return }
        loadingImages = true; error = nil
        defer { loadingImages = false; picked = [] }
        for item in items where draft.images.count < CareFeedbackDraft.maximumImages {
            let data = try? await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled else { return }
            if let data, let prepared = CareImageProcessor.jpeg(data) { draft.images.append(prepared) }
            else { error = L10n.text("Không đọc được một ảnh. Hãy chọn ảnh khác.") }
        }
    }

    private func send() async {
        guard let session, draft.canSend else { return }
        sending = true; error = nil
        defer { sending = false }
        do {
            try await session.feedback.send(draft, context: context)
            sent = true
        } catch {
            self.error = CloudError.normalize(error).localizedDescription
        }
    }
}
