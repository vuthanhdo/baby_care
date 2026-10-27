import SwiftUI

enum LegalDocument: String, Identifiable {
    case terms, privacy
    var version: String { self == .terms ? ConsentVersions.bundled.terms_version : ConsentVersions.bundled.privacy_version }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .terms: L10n.text("Điều khoản sử dụng")
        case .privacy: L10n.text("Chính sách quyền riêng tư")
        }
    }
}

struct OnboardingConsentView: View {
    @Bindable var model: ConsentViewModel
    let onAccept: () async -> Void
    let onBack: () async -> Void
    let onRetry: () async -> Void
    @State private var document: LegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(CareTheme.accent.opacity(0.12)).frame(width: 58, height: 58)
                            CareIcon(name: "Stitch_shield", color: CareTheme.accent, size: 28)
                        }
                        Text(L10n.text("Quyền riêng tư & dữ liệu của bé"))
                            .font(CareFont.title).multilineTextAlignment(.center)
                        Text(L10n.text("Trước khi bắt đầu, hãy xem cách BabyCare sử dụng và bảo vệ thông tin của bạn và bé."))
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity)

                    CareCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.text("BabyCare là ứng dụng hỗ trợ cha mẹ ghi nhận và theo dõi thông tin chăm sóc trẻ như sức khỏe, nhiệt độ, tiêm chủng, ăn uống, giấc ngủ và quá trình phát triển."))
                            Text(L10n.text("Một số thông tin bạn nhập có thể là dữ liệu cá nhân và dữ liệu sức khỏe của trẻ, vì vậy BabyCare cần sự đồng ý của bạn trước khi xử lý các thông tin này."))
                            Divider()
                            Label {
                                Text(L10n.text("BabyCare chỉ hỗ trợ ghi nhận và theo dõi thông tin chăm sóc trẻ. Ứng dụng không cung cấp dịch vụ khám bệnh, chẩn đoán hoặc điều trị và không thay thế tư vấn của bác sĩ hoặc nhân viên y tế có chuyên môn."))
                            } icon: {
                                CareIcon(name: "Stitch_medical_services", color: CareTheme.accent, size: 20)
                            }
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        }
                    }

                    sectionLabel("Tài liệu bạn nên xem")
                    CareCard {
                        VStack(spacing: 0) {
                            documentRow(.terms, icon: "doc.text", subtitle: "Điều kiện sử dụng BabyCare và giới hạn trách nhiệm")
                            Divider().padding(.leading, 44)
                            documentRow(.privacy, icon: "lock.shield", subtitle: "Dữ liệu được thu thập, mục đích sử dụng, lưu trữ và quyền của bạn")
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        sectionLabel("Sự đồng ý của bạn")
                        Spacer()
                        Text(L10n.text("{0} / 3 đã chọn", "\(selectedCount)"))
                            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }
                    CareCard {
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 8) {
                                checkbox($model.terms, label: L10n.text("Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư của BabyCare."), id: "consent.terms")
                                Text(termsText)
                                    .environment(\.openURL, OpenURLAction { url in
                                        document = url.host == "terms" ? .terms : .privacy
                                        return .handled
                                    })
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                            }
                            Divider().padding(.leading, 52)
                            consentRow($model.health, text: "Tôi đồng ý để BabyCare thu thập, lưu trữ và xử lý dữ liệu tôi cung cấp, bao gồm dữ liệu sức khỏe của trẻ, nhằm cung cấp các chức năng theo dõi và quản lý chăm sóc trẻ.", id: "consent.data")
                            Divider().padding(.leading, 52)
                            consentRow($model.representative, text: "Tôi xác nhận tôi là cha/mẹ, người giám hộ hoặc người đại diện hợp pháp có quyền cung cấp và quản lý thông tin của trẻ.", id: "consent.guardian")
                        }
                    }
                    if let error = model.error {
                        CareCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(error, systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(CareTheme.medical).accessibilityIdentifier("consent.error")
                                Button(L10n.text("Thử lại")) { Task { await onRetry() } }
                                    .font(CareFont.subheadline.weight(.semibold)).disabled(model.busy)
                            }
                        }
                    }
                }
                .font(CareFont.subheadline).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(CareTheme.background)
            .navigationTitle(L10n.text("Quyền riêng tư")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CareTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await onBack() } } label: { Image(systemName: "chevron.left") }
                        .disabled(model.busy).accessibilityLabel(L10n.text("Quay lại"))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    CarePrimaryButton(title: L10n.text("Đồng ý & Tiếp tục"), icon: "Stitch_arrow_forward", isLoading: model.busy) {
                        Task { await onAccept() }
                    }
                    .disabled(!model.canSubmit).accessibilityIdentifier("onboardingConsentButton")
                    Button(L10n.text("Quay lại")) { Task { await onBack() } }
                        .font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                        .frame(minHeight: 44).disabled(model.busy)
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
                .background(.ultraThinMaterial).overlay(alignment: .top) { Divider() }
            }
            .sheet(item: $document) { item in
                NavigationStack {
                    LegalDocumentView(document: item)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.text("Đóng")) { document = nil }
                        } }
                }
            }
        }
        .task { if model.status == nil { _ = await model.refresh() } }
        .interactiveDismissDisabled()
    }

    private var selectedCount: Int { [model.terms, model.health, model.representative].filter { $0 }.count }

    private func sectionLabel(_ text: String) -> some View {
        Text(L10n.text(text).uppercased()).font(CareFont.caption.weight(.semibold))
            .foregroundStyle(CareTheme.secondary).tracking(0.5)
    }

    private var termsText: AttributedString {
        var text = AttributedString(L10n.text("Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư của BabyCare."))
        if let range = text.range(of: L10n.text("Điều khoản sử dụng")) { text[range].link = URL(string: "babycare-legal://terms") }
        if let range = text.range(of: L10n.text("Chính sách quyền riêng tư")) { text[range].link = URL(string: "babycare-legal://privacy") }
        return text
    }
    private func checkbox(_ selected: Binding<Bool>, label: String, id: String) -> some View {
        Button { selected.wrappedValue.toggle() } label: {
            Image(systemName: selected.wrappedValue ? "checkmark.square.fill" : "square")
                .font(.title2).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).foregroundStyle(CareTheme.accent).disabled(model.busy)
        .accessibilityLabel(label)
        .accessibilityValue(selected.wrappedValue ? L10n.text("Đã chọn") : L10n.text("Chưa chọn"))
        .accessibilityAddTraits(selected.wrappedValue ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
    private func consentRow(_ selected: Binding<Bool>, text: String, id: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            checkbox(selected, label: L10n.text(text), id: id)
            Text(L10n.text(text)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
        }
    }
    private func documentRow(_ item: LegalDocument, icon: String, subtitle: String) -> some View {
        Button { document = item } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(CareTheme.accent)
                    .frame(width: 32, height: 32).background(CareTheme.accent.opacity(0.1), in: .circle)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(CareFont.subheadline.bold())
                    Text(L10n.text(subtitle)).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }.padding(.vertical, 12).frame(minHeight: 56)
        }.buttonStyle(.plain).accessibilityIdentifier("consent.document." + item.rawValue)
    }
}

struct ConsentStatusView: View {
    @Environment(SessionViewModel.self) private var session: SessionViewModel?
    var body: some View {
        List {
            if let local = session?.consent.acceptedLocallyAt, session?.consent.status == nil {
                Section(L10n.text("Trạng thái đồng ý dữ liệu")) {
                    LabeledContent(L10n.text("Đã đồng ý trên thiết bị"), value: local.careFormatted(date: .abbreviated, time: .shortened))
                    Text(L10n.text("Sẽ được ghi nhận trên máy chủ khi kết nối được.")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }
            if let status = session?.consent.status {
                Section(L10n.text("Phiên bản hiện tại")) {
                    LabeledContent(L10n.text("Điều khoản sử dụng"), value: status.required.terms_version)
                    LabeledContent(L10n.text("Chính sách quyền riêng tư"), value: status.required.privacy_version)
                    LabeledContent(L10n.text("Xử lý dữ liệu sức khỏe"), value: status.required.health_version)
                }
                if let accepted = status.accepted {
                    Section(L10n.text("Trạng thái đồng ý dữ liệu")) {
                        Text(L10n.text(status.isCurrent ? "Đã đồng ý" : "Cần đồng ý lại"))
                        LabeledContent(L10n.text("Điều khoản sử dụng"), value: accepted.terms_accepted_at)
                        LabeledContent(L10n.text("Chính sách quyền riêng tư"), value: accepted.privacy_accepted_at)
                        LabeledContent(L10n.text("Xử lý dữ liệu sức khỏe"), value: accepted.health_accepted_at)
                        LabeledContent(L10n.text("Xác nhận người đại diện"), value: accepted.representative_confirmed_at)
                    }
                } else { Text(L10n.text("Chưa đồng ý")) }
            } else { Text(L10n.text("Chưa kiểm tra được sự đồng ý. Hãy kiểm tra kết nối và thử lại.")) }
        }
        .navigationTitle(L10n.text("Trạng thái đồng ý dữ liệu"))
        .task { await session?.checkConsent() }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    CareIcon(name: document == .terms ? "Stitch_menu_book" : "Stitch_lock", color: CareTheme.accent, size: 36)
                    Text(document.title).font(CareFont.largeTitle)
                    Text(L10n.text("Phiên bản {0}", document.version))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(CareFont.title3.bold())
                        Text(section.body).font(CareFont.body).foregroundStyle(CareTheme.secondary)
                    }
                    .padding(16).background(CareTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CareTheme.border))
                }
                Text(L10n.text("Nội dung này mô tả cách BabyCare hiện đang hoạt động và không phải tư vấn pháp lý hoặc y tế."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }
            .padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(CareTheme.background)
        .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
    }

    private var sections: [(title: String, body: String)] {
        switch document {
        case .terms:
            [
                (L10n.text("1. Phạm vi dịch vụ"), L10n.text("BabyCare là công cụ ghi nhận và sắp xếp thông tin chăm sóc do người dùng cung cấp. Ứng dụng không khám bệnh, chẩn đoán, kê đơn, tính liều hoặc thay thế bác sĩ và nhân viên y tế.")),
                (L10n.text("2. Tài khoản và hồ sơ trẻ"), L10n.text("Bạn chịu trách nhiệm bảo vệ tài khoản, cung cấp thông tin chính xác trong khả năng của mình và chỉ tạo hồ sơ trẻ khi là cha mẹ, người giám hộ hoặc có quyền hợp pháp phù hợp.")),
                (L10n.text("3. Sử dụng an toàn"), L10n.text("Không dùng BabyCare cho tình huống cấp cứu hoặc làm căn cứ duy nhất để quyết định điều trị. Khi trẻ có dấu hiệu nghiêm trọng, hãy liên hệ cơ sở y tế hoặc dịch vụ cấp cứu phù hợp.")),
                (L10n.text("4. Nội dung và chia sẻ"), L10n.text("Bạn kiểm soát dữ liệu mình nhập và nội dung chọn đưa vào báo cáo. Hãy kiểm tra người nhận trước khi chia sẻ PDF hoặc liên kết chứa thông tin của trẻ. Chỉ mời vào gia đình những người bạn tin cậy, vì họ sẽ thấy mọi hồ sơ bé của gia đình.")),
                (L10n.text("5. Góp ý và đề xuất tính năng"), L10n.text("Không gửi nội dung xúc phạm, quấy rối, khiêu dâm, bạo lực, phân biệt đối xử, vi phạm pháp luật hay quảng cáo, và không ghi thông tin cá nhân của bạn, của trẻ hay của người khác vào đề xuất. BabyCare không chấp nhận nội dung phản cảm hay người dùng lạm dụng: mọi đề xuất được duyệt trước khi hiện cho người khác, nội dung bị báo cáo được xem xét trong vòng 24 giờ và bị gỡ nếu vi phạm, và tài khoản vi phạm có thể bị khóa. Nhà phát triển có thể dùng góp ý và đề xuất để cải thiện ứng dụng nhưng không có nghĩa vụ thực hiện hay trả thù lao.")),
                (L10n.text("6. Xóa dữ liệu và chấm dứt"), L10n.text("Bạn có thể xóa riêng hồ sơ bé hoặc xóa tài khoản trong Cài đặt. Hành động xóa được xác nhận rõ vì dữ liệu đã xóa không thể khôi phục trong ứng dụng.")),
                (L10n.text("7. Thay đổi điều khoản"), L10n.text("Khi thay đổi quan trọng làm mở rộng mục đích xử lý dữ liệu, BabyCare sẽ hiển thị nội dung cập nhật và yêu cầu đồng thuận lại trước khi tiếp tục xử lý theo mục đích mới."))
            ]
        case .privacy:
            [
                (L10n.text("1. Dữ liệu được xử lý"), L10n.text("BabyCare xử lý hồ sơ trẻ, nhật ký chăm sóc và sức khỏe, số đo, tiêm chủng, lịch nhắc, ảnh bạn chọn và thông tin tài khoản đăng nhập. Micro chỉ được dùng khi bạn chủ động ghi bằng giọng nói. Vị trí gần đúng chỉ được dùng khi bạn bật thời tiết trên màn hình chính và không được lưu. Khi bạn gửi góp ý, BabyCare nhận nội dung bạn viết, ảnh chụp màn hình bạn đính kèm (có thể chứa thông tin của bé đang hiện trên màn hình) và thông tin kỹ thuật hiện trước khi gửi: phiên bản ứng dụng và iOS, kiểu máy, ngôn ngữ, chế độ lưu. Đề xuất tính năng, phiếu bình chọn và báo cáo nội dung được lưu kèm tài khoản của bạn.")),
                (L10n.text("2. Mục đích"), L10n.text("Dữ liệu được dùng để lưu nhật ký, hiển thị lịch sử và thống kê, tạo lời nhắc, đồng bộ khi bạn chọn cloud và tạo báo cáo do bạn chủ động chia sẻ. Góp ý và đề xuất được dùng để sửa lỗi, trả lời bạn khi bạn cho phép liên hệ, cải thiện ứng dụng và chọn tính năng sẽ làm.")),
                (L10n.text("3. Nơi lưu dữ liệu"), L10n.text("Ở chế độ thiết bị, hồ sơ và nhật ký nằm trong vùng lưu trữ của ứng dụng trên máy. Tài khoản và bản ghi đồng ý vẫn được xử lý trên Supabase. Ở chế độ cloud, dữ liệu được đồng bộ với Supabase và có cache tách riêng theo tài khoản và gia đình.")),
                (L10n.text("4. Dữ liệu trẻ em và đồng thuận"), L10n.text("Trước khi tạo hoặc chỉnh sửa dữ liệu của bé, người dùng phải đồng ý với tài liệu hiện hành, việc xử lý dữ liệu sức khỏe và xác nhận có quyền đại diện hợp pháp. Server ghi lại phiên bản và thời điểm xác nhận; thay đổi phiên bản có thể yêu cầu đồng ý lại.")),
                (L10n.text("5. Chia sẻ"), L10n.text("Chế độ cloud sử dụng Supabase để xác thực, lưu dữ liệu và ảnh. Chủ gia đình có thể mời người khác bằng mã dùng một lần, với vai trò cùng chăm sóc (xem và ghi) hoặc chỉ xem. Mọi thành viên thấy mọi hồ sơ bé trong gia đình và email của nhau; chủ gia đình có thể đổi vai trò hoặc gỡ thành viên, và thành viên có thể tự rời gia đình. Báo cáo được gửi qua chức năng chia sẻ do bạn chọn. Nhập giọng nói dùng Apple Speech; khi thiết bị không hỗ trợ nhận dạng tại chỗ, âm thanh có thể được xử lý qua dịch vụ của Apple. Thời tiết lấy từ Apple Weather (WeatherKit) bằng vị trí gần đúng của bạn. Góp ý và ảnh đính kèm chỉ nhà phát triển xem được. Đề xuất tính năng chỉ hiện cho người dùng khác sau khi nhà phát triển duyệt, gồm tiêu đề, mô tả và số phiếu, không kèm thông tin của người gửi; ai đã bình chọn cũng không được hiển thị.")),
                (L10n.text("6. Lưu giữ và xóa"), L10n.text("Dữ liệu được giữ khi hồ sơ hoặc tài khoản còn hoạt động. Chỉ chủ gia đình xóa được hồ sơ bé, và việc xóa áp dụng cho mọi thành viên. Xóa tài khoản sẽ xóa các gia đình chỉ có bạn sử dụng, dữ liệu cloud, ảnh và cache của tài khoản trên thiết bị này. Gia đình còn thành viên khác không bị xóa: thành viên lâu nhất trở thành chủ gia đình và giữ dữ liệu của gia đình, kể cả những gì bạn đã ghi. Góp ý, ảnh đính kèm, đề xuất, phiếu bình chọn và báo cáo được giữ không lâu hơn tài khoản của bạn: xóa tài khoản sẽ xóa cả những dữ liệu này, và đề xuất bạn đã gửi không còn hiện cho người khác.")),
                (L10n.text("7. Quyền của bạn"), L10n.text("Bạn có thể xem, sửa, xuất báo cáo và xóa hồ sơ hoặc tài khoản trong Cài đặt. Màn trạng thái đồng ý hiển thị phiên bản và thời điểm đã xác nhận. Ứng dụng chưa có chức năng rút lại từng loại đồng ý riêng biệt.")),
                (L10n.text("8. Quyền thiết bị và bảo mật"), L10n.text("BabyCare xin quyền ảnh, camera, micro, vị trí và thông báo đúng lúc dùng tính năng tương ứng. Dữ liệu cloud được truyền qua HTTPS và quyền truy cập được giới hạn bằng phiên đăng nhập cùng chính sách cách ly gia đình."))
            ]
        }
    }
}
