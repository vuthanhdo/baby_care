import SwiftUI

/// The feature board in the "Góp ý" tab: published suggestions with their vote counts, most wanted first, and the
/// parent's own suggestions waiting for review. Authors are never shown (migration 0014).
struct FeatureBoardView: View {
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    @State private var items: [CareFeatureRequest] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var notice: String?
    @State private var suggesting = false
    @State private var reporting: CareFeatureRequest?
    @State private var voting: Set<UUID> = []
    @Environment(\.locale) private var appLocale

    private var mine: [CareFeatureRequest] { items.filter { $0.mine && !$0.status.isPublished } }
    private var published: [CareFeatureRequest] { items.filter(\.status.isPublished) }

    var body: some View {
        let _ = appLocale
        List {
            Section {
                Button { suggesting = true } label: {
                    Label { Text(L10n.text("Đề xuất tính năng mới")).font(CareFont.subheadline.weight(.semibold)) }
                        icon: { CareIcon(name: "Stitch_lightbulb", color: CareTheme.accent, size: 20) }
                }
                .disabled(session?.canSendFeedback != true)
                .accessibilityIdentifier("features.suggest")
            } footer: {
                Text(L10n.text("Đề xuất hiện cho mọi người sau khi được duyệt. Tên của bạn không được hiển thị."))
            }
            if let notice {
                Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(CareTheme.accent).font(CareFont.subheadline) }
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(CareTheme.medical).font(CareFont.subheadline) }
            }
            if !mine.isEmpty {
                Section(L10n.text("Đề xuất của bạn")) { ForEach(mine) { row($0) } }
            }
            Section(L10n.text("Mọi người đang muốn")) {
                // The board needs an account: without one there is nothing to show, not an empty board.
                if session?.canSendFeedback != true {
                    Text(L10n.text("Hãy đăng nhập để bình chọn và đề xuất tính năng.")).foregroundStyle(CareTheme.secondary)
                } else if !loaded {
                    HStack { ProgressView(); Text(L10n.text("Đang tải…")).foregroundStyle(CareTheme.secondary) }
                } else if published.isEmpty {
                    Text(L10n.text("Chưa có đề xuất nào. Hãy gửi đề xuất đầu tiên!")).foregroundStyle(CareTheme.secondary)
                } else {
                    ForEach(published) { row($0) }
                }
            }
        }
        .font(CareFont.subheadline)
        .scrollContentBackground(.hidden)
        .task { await load() }
        // A fresh board replaces the last thanks; the Task is not cancelled with the gesture.
        .refreshable { notice = nil; await Task { await load() }.value }
        .sheet(isPresented: $suggesting) {
            SuggestFeatureSheet { notice = L10n.text("Cảm ơn bạn! Đề xuất sẽ hiện cho mọi người sau khi được duyệt."); await load() }
        }
        .confirmationDialog(L10n.text("Báo cáo đề xuất này?"), isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                            titleVisibility: .visible, presenting: reporting) { item in
            Button(L10n.text("Báo cáo nội dung không phù hợp"), role: .destructive) { Task { await report(item) } }
        } message: { _ in Text(L10n.text("Nhà phát triển sẽ xem lại và ẩn đề xuất nếu nội dung không phù hợp.")) }
    }

    private func row(_ item: CareFeatureRequest) -> some View {
        HStack(alignment: .top, spacing: 14) {
            voteButton(item)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.text)
                if !item.details.isEmpty {
                    Text(item.details).font(CareFont.footnote).foregroundStyle(CareTheme.secondary).lineLimit(4)
                }
                if let badge = item.status.badge {
                    Text(badge).font(CareFont.caption2.weight(.semibold))
                        .foregroundStyle(item.status == .done ? CareTheme.accent : CareTheme.routine)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((item.status == .done ? CareTheme.accent : CareTheme.routine).opacity(0.12), in: .capsule)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contextMenu {
            if item.status.isPublished && !item.mine {
                Button(L10n.text("Báo cáo nội dung không phù hợp"), systemImage: "flag") { reporting = item }
            }
        }
    }

    private func voteButton(_ item: CareFeatureRequest) -> some View {
        Button { Task { await toggle(item) } } label: {
            VStack(spacing: 2) {
                Image(systemName: item.voted ? "arrowtriangle.up.fill" : "arrowtriangle.up").font(.body.weight(.semibold))
                Text(verbatim: "\(item.votes)").font(CareFont.subheadline.weight(.bold)).monospacedDigit()
            }
            .foregroundStyle(item.voted ? CareTheme.accent : CareTheme.secondary)
            .frame(width: 52, height: 56)
            .background(item.voted ? CareTheme.accent.opacity(0.12) : CareTheme.background, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(item.voted ? CareTheme.accent.opacity(0.5) : CareTheme.border))
        }
        .buttonStyle(.plain)
        .disabled(!item.status.votable || voting.contains(item.id) || session?.canSendFeedback != true)
        .accessibilityIdentifier("features.vote.\(item.id.uuidString)")
        .accessibilityLabel(item.voted ? L10n.text("Bỏ bình chọn") : L10n.text("Bình chọn"))
        .accessibilityValue(L10n.count(item.votes, one: "1 phiếu", many: "{0} phiếu"))
    }

    private func load() async {
        guard let session, session.canSendFeedback else { loaded = true; return }
        do { items = try await session.features.board(); error = nil }
        catch { self.error = CloudError.normalize(error).localizedDescription }
        loaded = true
    }

    /// Optimistic: the count changes at once, then follows the server's answer (or reverts on failure).
    private func toggle(_ item: CareFeatureRequest) async {
        guard let session, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        voting.insert(item.id); defer { voting.remove(item.id) }
        let before = items[index]
        items[index].voted.toggle()
        items[index].votes += items[index].voted ? 1 : -1
        do {
            let result = try await session.features.toggleVote(id: item.id)
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].voted = result.voted; items[i].votes = result.votes }
            error = nil
        } catch {
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = before }
            self.error = CloudError.normalize(error).localizedDescription
        }
    }

    private func report(_ item: CareFeatureRequest) async {
        guard let session else { return }
        do { try await session.features.report(id: item.id); notice = L10n.text("Đã gửi báo cáo. Cảm ơn bạn."); error = nil }
        catch { self.error = CloudError.normalize(error).localizedDescription }
    }
}

/// A new suggestion: a short title and optional details. The id is fixed for the sheet, so a retry never duplicates.
private struct SuggestFeatureSheet: View {
    var onSubmitted: () async -> Void
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var id = UUID()
    @State private var title = ""
    @State private var details = ""
    @State private var sending = false
    @State private var error: String?
    @FocusState private var focused: Bool
    @Environment(\.locale) private var appLocale

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool { (3...120).contains(trimmedTitle.count) && details.count <= 1000 }

    var body: some View {
        let _ = appLocale
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.text("Ví dụ: Nhắc bé uống nước"), text: $title)
                        .focused($focused).accessibilityIdentifier("features.title")
                } header: { Text(L10n.text("Tính năng bạn muốn")) } footer: {
                    Text(verbatim: "\(trimmedTitle.count)/120")
                }
                Section {
                    TextField(L10n.text("Mô tả thêm: dùng khi nào, giúp gì cho bạn (không bắt buộc)"), text: $details, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("features.details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("Đừng ghi tên, số điện thoại hay thông tin của bé: đề xuất sẽ hiện cho mọi người sau khi được duyệt."))
                        Text(verbatim: "\(details.count)/1000").foregroundStyle(details.count > 1000 ? CareTheme.medical : CareTheme.secondary)
                    }
                }
                if let error { Section { Text(error).foregroundStyle(CareTheme.medical) } }
            }
            .navigationTitle(L10n.text("Đề xuất tính năng")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if sending { ProgressView() } else {
                        Button(L10n.text("Gửi")) { Task { await submit() } }
                            .disabled(!valid).accessibilityIdentifier("features.submit")
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(sending)
    }

    private func submit() async {
        guard let session, valid else { return }
        sending = true; error = nil
        defer { sending = false }
        do {
            try await session.features.submit(id: id, title: trimmedTitle, details: details.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
            await onSubmitted()
        } catch {
            self.error = CloudError.normalize(error).localizedDescription
        }
    }
}
