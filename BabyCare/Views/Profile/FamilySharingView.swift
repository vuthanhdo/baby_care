import SwiftUI

/// Settings → "Gia đình & chia sẻ": the families this account belongs to, their members, invites and joining by code.
/// Sharing is per family: a member sees and (unless a viewer) logs for every baby in it.
struct FamilySharingView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var sharing: CloudFamilySharing?
    @State private var error: String?
    @State private var working = false
    @State private var created: CloudCreatedInvite?
    @State private var joining = false
    @State private var leaving = false
    @State private var removing: CloudFamilyMember?

    @Environment(\.locale) private var appLocale
    private var isOwner: Bool { sharing?.role == .owner }

    var body: some View {
        let _ = appLocale
        List {
            Section {
                if let family = session.currentFamily {
                    LabeledContent(L10n.text("Đang mở"), value: session.title(of: family))
                    LabeledContent(L10n.text("Vai trò của bạn"), value: family.role.title)
                }
                if session.families.count > 1 {
                    ForEach(session.families) { family in
                        Button {
                            Task { await session.switchFamily(family.id); await reload() }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title(of: family)).foregroundStyle(CareTheme.text)
                                    Text(family.role.title).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                }
                                Spacer()
                                if family.id == session.familyID { Image(systemName: "checkmark").foregroundStyle(CareTheme.accent) }
                            }
                        }
                        .accessibilityIdentifier("family.switch.\(family.id.uuidString)")
                    }
                }
            } header: { Text(L10n.text("Gia đình")) } footer: {
                Text(L10n.text("Người trong gia đình thấy email của nhau và mọi hồ sơ bé của gia đình. Người cùng chăm sóc ghi được; người chỉ xem thì không."))
            }

            if let sharing {
                Section(L10n.text("Thành viên")) {
                    ForEach(sharing.members) { member in
                        memberRow(member)
                    }
                }
                if isOwner {
                    Section {
                        ForEach([CareFamilyRole.caregiver, .viewer], id: \.self) { role in
                            Button { Task { await invite(role) } } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Label(L10n.text("Mời: {0}", role.title), systemImage: "person.badge.plus")
                                    Text(role.summary).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                }
                            }
                            .disabled(working)
                            .accessibilityIdentifier("family.invite.\(role.rawValue)")
                        }
                        ForEach(sharing.invites) { invite in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.text("Lời mời {0}", invite.role.title.lowercased()))
                                    Text(L10n.text("Hết hạn {0}", invite.expiresAt.careFormatted(date: .abbreviated, time: .shortened)))
                                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                }
                                Spacer()
                                Button(L10n.text("Hủy"), role: .destructive) { Task { await revoke(invite) } }.buttonStyle(.borderless)
                            }
                        }
                    } header: { Text(L10n.text("Mời người chăm sóc")) } footer: {
                        Text(L10n.text("Mỗi mã dùng một lần và hết hạn sau 48 giờ. Người được mời cần tài khoản Bé Khỏe trên cloud."))
                    }
                }
            } else if error == nil {
                Section { HStack { ProgressView(); Text(L10n.text("Đang tải thành viên…")).foregroundStyle(CareTheme.secondary) } }
            }

            Section {
                Button { joining = true } label: { Label(L10n.text("Nhập mã mời"), systemImage: "key") }
                    .accessibilityIdentifier("family.join")
                if !session.isOwnFamily, let family = session.currentFamily {
                    Button(L10n.text("Rời gia đình này"), role: .destructive) { leaving = true }
                        .confirmationDialog(L10n.text("Rời {0}?", session.title(of: family)), isPresented: $leaving, titleVisibility: .visible) {
                            Button(L10n.text("Rời gia đình"), role: .destructive) { Task { await leave(family.id) } }
                        } message: { Text(L10n.text("Bạn sẽ không xem và ghi được cho các bé của gia đình này nữa. Dữ liệu của gia đình vẫn giữ nguyên.")) }
                }
            } header: { Text(L10n.text("Tham gia gia đình khác")) }

            if let error {
                Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(CareTheme.medical).font(CareFont.subheadline) }
            }
        }
        .font(CareFont.subheadline)
        .navigationTitle(L10n.text("Gia đình & chia sẻ")).navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await session.refreshFamilies(); await reload() }
        .sheet(item: Binding(get: { created.map(InviteSheetItem.init) }, set: { if $0 == nil { created = nil } })) { item in
            InviteCodeSheet(invite: item.invite)
        }
        .sheet(isPresented: $joining) { JoinFamilySheet() }
        .confirmationDialog(L10n.text("Gỡ {0} khỏi gia đình?", removing?.email ?? ""), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { member in
            Button(L10n.text("Gỡ khỏi gia đình"), role: .destructive) { Task { await remove(member) } }
        } message: { _ in Text(L10n.text("Người này sẽ không xem và ghi được nữa. Những gì họ đã ghi vẫn được giữ.")) }
    }

    @ViewBuilder private func memberRow(_ member: CloudFamilyMember) -> some View {
        let isMe = member.email.caseInsensitiveCompare(session.email) == .orderedSame
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(isMe ? L10n.text("{0} (bạn)", member.email) : member.email).foregroundStyle(CareTheme.text)
                Text(member.role.title).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            Spacer()
            if isOwner, !isMe, member.role != .owner {
                Menu {
                    let other: CareFamilyRole = member.role == .viewer ? .caregiver : .viewer
                    Button(L10n.text("Đổi thành: {0}", other.title)) { Task { await setRole(member, other) } }
                    Button(L10n.text("Gỡ khỏi gia đình"), role: .destructive) { removing = member }
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                    .accessibilityLabel(L10n.text("Quản lý {0}", member.email))
            }
        }
    }

    private func reload() async {
        guard let id = session.familyID else { return }
        do { sharing = try await session.sharing.sharing(familyID: id); error = nil }
        catch { self.error = error.localizedDescription }
    }
    private func perform(_ action: () async throws -> Void) async {
        working = true; defer { working = false }
        do { try await action(); error = nil; await session.refreshFamilies(); await reload() }
        catch { self.error = error.localizedDescription }
    }
    private func invite(_ role: CareFamilyRole) async {
        guard let id = session.familyID else { return }
        await perform { created = try await session.sharing.createInvite(familyID: id, role: role) }
    }
    private func revoke(_ invite: CloudFamilyInvite) async {
        await perform { try await session.sharing.revokeInvite(id: invite.id) }
    }
    private func setRole(_ member: CloudFamilyMember, _ role: CareFamilyRole) async {
        guard let id = session.familyID else { return }
        await perform { try await session.sharing.setRole(familyID: id, userID: member.userID, role: role) }
    }
    private func remove(_ member: CloudFamilyMember) async {
        guard let id = session.familyID else { return }
        await perform { try await session.sharing.removeMember(familyID: id, userID: member.userID) }
    }
    private func leave(_ id: UUID) async {
        if let problem = await session.leaveFamily(id) { error = problem }
    }
}

private struct InviteSheetItem: Identifiable {
    let invite: CloudCreatedInvite
    var id: String { invite.code }
}

/// Shows a new code once, large enough to read aloud, with the message to send.
private struct InviteCodeSheet: View {
    let invite: CloudCreatedInvite
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            VStack(spacing: 20) {
                Text(L10n.text("Mã mời {0}", invite.invite.role.title.lowercased())).font(CareFont.headline)
                Text(CareInviteCode.display(invite.code))
                    .font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundStyle(CareTheme.accent)
                    .textSelection(.enabled).accessibilityIdentifier("family.code")
                Text(L10n.text("Dùng một lần · hết hạn {0}", invite.invite.expiresAt.careFormatted(date: .abbreviated, time: .shortened)))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                ShareLink(item: CareInviteCode.message(code: invite.code, role: invite.invite.role)) {
                    Label(L10n.text("Gửi lời mời"), systemImage: "square.and.arrow.up").font(CareFont.headline)
                        .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 52)
                        .background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                Text(L10n.text("Người nhận tải Bé Khỏe, đăng nhập rồi nhập mã trong Cài đặt → Gia đình & chia sẻ. Mã chỉ hiện một lần."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .navigationTitle(L10n.text("Mời người chăm sóc")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Xong")) { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

private struct JoinFamilySheet: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var problem: String?
    @State private var joining = false
    @FocusState private var focused: Bool
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.text("8 ký tự, ví dụ ABCD EFGH"), text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced)).focused($focused)
                        .accessibilityIdentifier("family.joinCode")
                } footer: {
                    Text(L10n.text("Sau khi tham gia, app mở gia đình mới. Gia đình của bạn vẫn còn và đổi qua lại được trong màn này."))
                }
                if let problem { Section { Text(problem).foregroundStyle(CareTheme.medical) } }
            }
            .navigationTitle(L10n.text("Nhập mã mời")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Tham gia")) {
                        Task {
                            joining = true
                            problem = await session.joinFamily(code: code)
                            joining = false
                            if problem == nil { dismiss() }
                        }
                    }
                    .disabled(!CareInviteCode.isComplete(code) || joining)
                    .accessibilityIdentifier("family.joinConfirm")
                }
            }
            .onAppear { focused = true }
        }.presentationDetents([.medium])
    }
}
