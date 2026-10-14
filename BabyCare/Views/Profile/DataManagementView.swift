import Foundation
import SwiftUI

nonisolated enum DestructiveConfirmation {
    static func matches(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN")) == "xoa"
    }
}

struct DataManagementView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var confirmBabyDeletion = false
    @State private var confirmAccountDeletion = false
    @State private var accountConfirmation = ""
    @State private var deletingAll = false

    private var isCloudAccount: Bool { session?.phase == .content && session?.isLocal == false }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    CareIcon(name: "Stitch_verified_user", color: CareTheme.accent, size: 34)
                    Text(L10n.text("Xóa & Quản lý dữ liệu")).font(CareFont.title)
                    Text(L10n.text("Bạn có quyền kiểm soát dữ liệu của gia đình. Hãy xuất báo cáo cần giữ trước khi xóa; dữ liệu đã xóa không thể khôi phục trong ứng dụng."))
                        .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                }.padding(.vertical, 8)
            }

            Section(L10n.text("Sao lưu trước khi xóa")) {
                NavigationLink { ShareReportView() } label: {
                    Label(L10n.text("Tạo và lưu báo cáo PDF"), systemImage: "arrow.down.doc")
                }
                Text(L10n.text("Báo cáo chỉ chứa bé và khoảng thời gian bạn chọn; đây không phải bản xuất toàn bộ tài khoản."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }

            Section(L10n.text("Hồ sơ bé đang chọn")) {
                LabeledContent(L10n.text("Bé"), value: viewModel.baby.name)
                LabeledContent(L10n.text("Hoạt động"), value: "\(viewModel.activities.count)")
                LabeledContent(L10n.text("Số đo cơ thể"), value: "\(viewModel.measurements.count)")
                LabeledContent(L10n.text("Tiêm chủng"), value: "\(viewModel.vaccinations.count)")
                LabeledContent(L10n.text("Lịch nhắc"), value: "\(viewModel.medicationReminders.count)")
                Text(L10n.text("Xóa hồ sơ sẽ xóa thông tin bé, nhật ký, số đo, tiêm chủng, lịch nhắc và ảnh đính kèm của bé này."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                Button(L10n.text("Xóa toàn bộ dữ liệu {0}", viewModel.baby.name), systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                    confirmBabyDeletion = true
                }
                .disabled(viewModel.state.isSaving || deletingAll)
                .accessibilityIdentifier("data.deleteBaby")
            }

            Section(L10n.text(isCloudAccount ? "Hủy tài khoản & xóa toàn bộ" : "Xóa toàn bộ dữ liệu trên thiết bị")) {
                if isCloudAccount {
                    Text(L10n.text("Xóa tài khoản sẽ xóa mọi gia đình do tài khoản sở hữu, toàn bộ hồ sơ bé, dữ liệu cloud và cache của tài khoản trên thiết bị này; sau đó bạn sẽ được đăng xuất."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    if let email = session?.email, !email.isEmpty { LabeledContent(L10n.text("Tài khoản"), value: email) }
                    Button(L10n.text("Xóa vĩnh viễn tài khoản & toàn bộ dữ liệu"), systemImage: "trash", role: .destructive) {
                        accountConfirmation = ""
                        confirmAccountDeletion = true
                    }
                    .disabled(session?.busy == true || viewModel.state.isSaving)
                    .accessibilityIdentifier("data.deleteAccount")
                } else {
                    Text(L10n.text("Thao tác này xóa mọi hồ sơ và nhật ký trong kho dữ liệu trên thiết bị. Ứng dụng sẽ quay lại onboarding."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    Button(L10n.text("Xóa toàn bộ dữ liệu trên thiết bị"), systemImage: "trash", role: .destructive) {
                        accountConfirmation = ""
                        confirmAccountDeletion = true
                    }
                    .disabled(viewModel.state.isSaving || deletingAll)
                }
            }

            Section {
                Text(L10n.text("Việc xóa được thực hiện trực tiếp với kho dữ liệu đang dùng. Nếu cloud chưa kết nối, BabyCare sẽ giữ nguyên dữ liệu và báo lỗi thay vì chỉ xóa bản hiển thị trên máy."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }

            if let deletionError = session?.error ?? viewModel.state.error {
                Section(L10n.text("Chưa hoàn tất thao tác")) {
                    Text(deletionError).foregroundStyle(CareTheme.medical)
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle(L10n.text("Quản lý dữ liệu")).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.text("Xóa hồ sơ {0}?", viewModel.baby.name), isPresented: $confirmBabyDeletion, titleVisibility: .visible) {
            Button(L10n.text("Xóa vĩnh viễn dữ liệu {0}", viewModel.baby.name), role: .destructive) { deleteSelectedBaby() }
            Button(L10n.text("Hủy"), role: .cancel) { }
        } message: {
            Text(L10n.text("Toàn bộ dữ liệu liên quan tới bé này sẽ bị xóa và không thể hoàn tác."))
        }
        .alert(L10n.text(isCloudAccount ? "Xóa vĩnh viễn tài khoản?" : "Xóa toàn bộ dữ liệu?"), isPresented: $confirmAccountDeletion) {
            TextField(L10n.text("Nhập XÓA để xác nhận"), text: $accountConfirmation)
                .textInputAutocapitalization(.characters)
            Button(L10n.text("Xóa vĩnh viễn"), role: .destructive) { deleteEverything() }
                .disabled(!DestructiveConfirmation.matches(accountConfirmation))
            Button(L10n.text("Hủy"), role: .cancel) { accountConfirmation = "" }
        } message: {
            Text(L10n.text("Nhập XÓA để xác nhận hành động không thể hoàn tác này."))
        }
    }

    private func deleteSelectedBaby() {
        let id = viewModel.baby.id
        let name = viewModel.baby.name
        Task {
            _ = await viewModel.send(.commit(.deleteBaby(id), message: L10n.text("Đã xóa dữ liệu {0}", name)))
        }
    }

    private func deleteEverything() {
        accountConfirmation = ""
        if isCloudAccount, let session {
            Task { _ = await session.deleteAccount() }
        } else {
            let ids = viewModel.babies.map(\.id)
            deletingAll = true
            Task {
                for id in ids {
                    guard await viewModel.send(.commit(.deleteBaby(id))) else { deletingAll = false; return }
                }
                deletingAll = false
                dismiss()
            }
        }
    }
}
