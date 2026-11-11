import SwiftUI

/// Uploads what the previous backend left on this phone into the open family (`LegacyCloudRestore`).
/// Reached from onboarding and from Settings → Account while old caches remain.
struct LegacyRestoreView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDiscard = false

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Form {
            Section {
                Text(L10n.text("Bé Khỏe đã chuyển sang máy chủ mới và dữ liệu trên máy chủ cũ không chuyển sang được. Điện thoại này còn giữ một bản sao tới lần đồng bộ cuối, kèm ảnh. Khôi phục sẽ tải bản sao đó lên gia đình đang mở."))
                    .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
            } footer: {
                Text(L10n.text("Nếu cả nhà dùng chung một gia đình, chỉ một người khôi phục rồi mời những người còn lại."))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            ForEach(session.legacyBackups) { backup in
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(backup.babyNames.joined(separator: ", ")).font(CareFont.headline)
                        Text(summary(of: backup)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                    CareAsyncButton(L10n.text("Khôi phục vào gia đình này")) { await session.restoreLegacy(backup) }
                        .accessibilityIdentifier("restore.start")
                }
            }
            if let error = session.error {
                Section { Text(error).font(CareFont.subheadline).foregroundStyle(CareTheme.medical) }
            } else if session.legacyBackups.isEmpty, let message = session.message {
                Section { Label(message, systemImage: "checkmark.circle").font(CareFont.subheadline) }
            }
            if !session.legacyBackups.isEmpty {
                Section {
                    Button(L10n.text("Xóa bản cũ trên máy"), role: .destructive) { confirmDiscard = true }
                }
            }
        }
        .disabled(viewModel.state.restoring != nil)
        .navigationTitle(L10n.text("Khôi phục dữ liệu cũ"))
        .confirmationDialog(L10n.text("Xóa bản dữ liệu cũ trên máy?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L10n.text("Xóa"), role: .destructive) { session.discardLegacyBackups(); dismiss() }
        } message: {
            Text(L10n.text("Không thể hoàn tác. Dữ liệu đã khôi phục lên cloud không bị ảnh hưởng."))
        }
    }

    private func summary(of backup: LegacyCloudRestore.Backup) -> String {
        let records = L10n.count(backup.recordCount, one: "1 bản ghi", many: "{0} bản ghi")
        guard let latest = backup.latestEntry else { return records }
        return L10n.text("{0} · ghi gần nhất {1}", records, latest.careFormatted(date: .abbreviated, time: .omitted))
    }
}

/// Shown over the whole app while a restore runs: the screens are disabled meanwhile, and the restore started on
/// onboarding carries on after the first baby appears and onboarding closes.
struct CareRestoreProgressOverlay: View {
    let progress: RestoreProgress

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(spacing: 12) {
            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
            Text(L10n.text("Đang khôi phục dữ liệu cũ… {0}/{1}", "\(progress.done)", "\(progress.total)"))
                .font(CareFont.subheadline.weight(.semibold))
            Text(L10n.text("Giữ ứng dụng mở cho tới khi xong."))
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("restore.progress")
    }
}
