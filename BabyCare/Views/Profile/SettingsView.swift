import SwiftUI
import AVFAudio
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Stitch K — native view backed by the existing data provider.
struct SettingsView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @AppStorage("care.textSize") private var textSize = "system"
    @AppStorage("care.habitSuggestions") private var habitSuggestions = true
    @State private var showingTextSize = false
    @State private var showingPermissions = false
    @State private var showingAbout = false
    @State private var showingStorage = false
    @State private var showingGuide = false

    private var textSizeTitle: String {
        switch textSize { case "large": L10n.text("Lớn"); case "largest": L10n.text("Rất lớn"); default: L10n.text("Theo hệ thống iOS") }
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        List {
            Section {
                Text(L10n.text("Tùy chỉnh ứng dụng & dữ liệu của {0}", "\(viewModel.baby.name)"))
                    .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    .listRowBackground(Color.clear)
            }
            Section(L10n.text("Trải nghiệm & Hiển thị")) {
                LanguagePicker()
                Button { showingTextSize = true } label: {
                    settingsRow(L10n.text("Cỡ chữ"), subtitle: textSizeTitle, icon: "Stitch_format_size", color: CareTheme.accent)
                }.buttonStyle(.plain)
                Toggle(isOn: $habitSuggestions) {
                    settingsRow(L10n.text("Gợi ý theo thói quen"), subtitle: L10n.text("Gợi ý từ lần ghi gần đây; lịch đã đặt vẫn được giữ."), icon: "Stitch_auto_awesome", color: CareTheme.routine)
                }
                settingsRow(L10n.text("Đơn vị đo"), subtitle: L10n.text("°C, kg, cm, ml · Hệ đo lường tiêu chuẩn Việt Nam"), icon: "Stitch_straighten", color: CareTheme.feeding)
            }

            Section(L10n.text("Theo dõi & Nhắc nhở")) {
                NavigationLink { IllnessTrackingView() } label: {
                    settingsRow(L10n.text("Lịch nhắc thuốc"), subtitle: L10n.text("Kiểm tra lịch đã nhập cho bé"), icon: "Stitch_alarm", color: CareTheme.medical)
                }
                Button { showingPermissions = true } label: {
                    settingsRow(L10n.text("Quyền thông báo & Mic"), subtitle: L10n.text("Xem trạng thái quyền trên thiết bị"), icon: "Stitch_notifications_active", color: CareTheme.accent)
                }.buttonStyle(.plain)
            }

            CareAccountSection()

            Section(L10n.text("Dữ liệu & Báo cáo")) {
                NavigationLink { SharedReportSettingsView() } label: {
                    settingsRow(L10n.text("Liên kết báo cáo đã chia sẻ"), subtitle: L10n.text("Báo cáo PDF trên thiết bị"), icon: "Stitch_qr_code_2", color: CareTheme.feeding)
                }
                Button { showingStorage = true } label: {
                    settingsRow(viewModel.state.storage == .device ? L10n.text("Bộ nhớ trên thiết bị") : L10n.text("Dữ liệu cloud & cache"), subtitle: L10n.text("{0} hoạt động · {1} số đo của bé", "\(viewModel.activities.count)", "\(viewModel.measurements.count)"), icon: "Stitch_sd_storage", color: CareTheme.accent)
                }.buttonStyle(.plain)
            }

            Section(L10n.text("Hướng dẫn & Giới thiệu")) {
                Button { showingGuide = true } label: {
                    settingsRow(L10n.text("Hướng dẫn sử dụng 4 bước"), subtitle: L10n.text("Ghi nhanh, Tìm lại, Lịch thuốc, Chia sẻ"), icon: "Stitch_menu_book", color: CareTheme.accent)
                }.buttonStyle(.plain)
                Button { showingAbout = true } label: {
                    HStack(spacing: 13) {
                        CareBrandView(size: 44)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.text("Về ứng dụng Bé Khỏe")).font(CareFont.subheadline.weight(.semibold))
                            Text(L10n.text("Phiên bản {0}", "\(appVersion)")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        }
                    }.padding(.vertical, 5)
                }.buttonStyle(.plain)
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "Stitch_medical_information", color: CareTheme.medical, size: 18)
                    Text(L10n.text("Dữ liệu dùng để ghi nhận và trao đổi khi chăm sóc bé, không thay thế chẩn đoán hoặc chỉ định của nhân viên y tế."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                }.padding(.vertical, 6).listRowBackground(CareTheme.medicalBackground)
            }

            Section {
                Text(L10n.text("Thiết kế vì sự an tâm của Bố Mẹ · Bé Khỏe"))
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle(L10n.text("Cài đặt"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: habitSuggestions) { _, _ in Task { await viewModel.send(.showMessage(L10n.text("Đã lưu cài đặt gợi ý"))) } }
        .sheet(isPresented: $showingTextSize) {
            NavigationStack {
                Form {
                    Section {
                        Picker(L10n.text("Cỡ chữ"), selection: $textSize) {
                            Text(L10n.text("Theo thiết bị")).tag("system")
                            Text(L10n.text("Lớn")).tag("large")
                            Text(L10n.text("Rất lớn")).tag("largest")
                        }.pickerStyle(.inline)
                    }
                    Section(L10n.text("Xem trước")) {
                        Text(L10n.text("Ghi nhanh để chăm bé an tâm hơn")).font(CareFont.title2.bold())
                        Text(L10n.text("Tên, thời gian và nội dung được hiển thị rõ ràng trong nhật ký.")).font(CareFont.body)
                    }
                }
                .navigationTitle(L10n.text("Cỡ chữ")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Đóng")) { showingTextSize = false } } }
                .dynamicTypeSize(textSize == "largest" ? .accessibility1 : textSize == "large" ? .xxxLarge : .large)
                .onChange(of: textSize) { _, _ in Task { await viewModel.send(.showMessage(L10n.text("Đã đổi cỡ chữ"))) } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingPermissions) { NavigationStack { ProfilePermissionsView() } }
        .sheet(isPresented: $showingGuide) { NavigationStack { ProfileGuideView() } }
        .sheet(isPresented: $showingStorage) {
            NavigationStack {
                Form {
                    Section(L10n.text("Bé {0}", "\(viewModel.baby.name)")) {
                        LabeledContent(L10n.text("Hoạt động"), value: "\(viewModel.activities.count)")
                        LabeledContent(L10n.text("Số đo cơ thể"), value: "\(viewModel.measurements.count)")
                    }
                    Section {
                        if viewModel.state.storage == .device {
                            Text(L10n.text("Hồ sơ, nhật ký và số đo được lưu trên thiết bị này. Dữ liệu có thể mất khi xóa ứng dụng. Đăng nhập cloud không tự tải dữ liệu cũ lên."))
                        } else {
                            Text(viewModel.state.storage.message ?? L10n.text("Dữ liệu đã được server xác nhận và có cache SwiftData riêng cho tài khoản, gia đình này. Khi offline, thay đổi được lưu trên máy và tự đồng bộ khi có mạng."))
                        }
                        NavigationLink(L10n.text("Tạo báo cáo PDF")) { ShareReportView() }
                    }
                }
                .navigationTitle(L10n.text("Dữ liệu trên thiết bị")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Đóng")) { showingStorage = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAbout) {
            NavigationStack {
                Form {
                    Section {
                        Text(L10n.text("Bé Khỏe – Bố Mẹ An Tâm")).font(CareFont.title2.bold())
                        LabeledContent(L10n.text("Phiên bản"), value: appVersion)
                        Text(L10n.text("Ghi nhanh, tìm lại dễ dàng và theo dõi thông tin chăm sóc bé trong một ứng dụng."))
                    }
                    Section {
                        Text(L10n.text("Ứng dụng ghi nhận dữ liệu do gia đình cung cấp. Không tự chẩn đoán, kê đơn hoặc tính liều thuốc."))
                        Text(L10n.text("Bạn có thể dùng SwiftData trên thiết bị hoặc đăng nhập email để dùng dữ liệu cloud. Hai kho dữ liệu được giữ riêng cho tới khi bạn chủ động nhập dữ liệu."))
                    }
                }
                .navigationTitle(L10n.text("Về ứng dụng")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Đóng")) { showingAbout = false } } }
            }.presentationDetents([.medium, .large])
        }
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    private func settingsRow(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 13) {
            CareIcon(name: icon, color: color, size: 23)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.text)
                Text(subtitle).font(CareFont.footnote).foregroundStyle(CareTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 5)
    }
}

private struct ProfilePermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var microphone = L10n.text("Đang kiểm tra…")
    @State private var notifications = L10n.text("Đang kiểm tra…")

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Form {
            Section {
                LabeledContent(L10n.text("Micrô"), value: microphone)
                LabeledContent(L10n.text("Thông báo"), value: notifications)
            } footer: { Text(L10n.text("Ứng dụng chỉ yêu cầu quyền khi bạn dùng tính năng tương ứng.")) }
            #if canImport(UIKit)
            Section {
                Button(L10n.text("Mở cài đặt thiết bị")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            #endif
        }
        .navigationTitle(L10n.text("Quyền truy cập")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Đóng")) { dismiss() } } }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted: microphone = L10n.text("Đã cho phép")
        case .denied: microphone = L10n.text("Đã từ chối")
        case .undetermined: microphone = L10n.text("Chưa yêu cầu")
        @unknown default: microphone = L10n.text("Chưa xác định")
        }
        #else
        microphone = L10n.text("Kiểm tra trong cài đặt thiết bị")
        #endif
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notifications = L10n.text("Đã cho phép")
        case .denied: notifications = L10n.text("Đã từ chối")
        case .notDetermined: notifications = L10n.text("Chưa yêu cầu")
        @unknown default: notifications = L10n.text("Chưa xác định")
        }
    }
}

private struct ProfileGuideView: View {
    @Environment(\.dismiss) private var dismiss

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        List {
            DisclosureGroup(L10n.text("1. Ghi nhanh")) {
                Text(L10n.text("Chọn Y tế, Ăn uống hoặc Sinh hoạt; chọn hoạt động; kiểm tra dữ liệu rồi bấm Lưu. Thời điểm mặc định là hiện tại. Nội dung giọng nói cần xem lại trước khi lưu."))
            }
            DisclosureGroup(L10n.text("2. Tìm lại")) {
                Text(L10n.text("Mở Nhật ký để tìm theo từ khóa, ngày hoặc nhóm hoạt động. Chạm một bản ghi để xem chi tiết và chỉnh sửa."))
            }
            DisclosureGroup(L10n.text("3. Theo dõi thuốc")) {
                Text(L10n.text("Nhập lịch từ hướng dẫn bạn đang có và kiểm tra trước khi ghi đã dùng. Lời nhắc không tự tạo bản ghi và không thay thế chỉ định liều thuốc."))
            }
            DisclosureGroup(L10n.text("4. Chia sẻ báo cáo")) {
                Text(L10n.text("Trong Thống kê, chọn Chia sẻ báo cáo, chọn thời gian và nội dung, xem trước rồi xuất PDF. Báo cáo phản ánh dữ liệu tại thời điểm tạo."))
            }
        }
        .navigationTitle(L10n.text("Hướng dẫn sử dụng")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Đóng")) { dismiss() } } }
    }
}

private struct SharedReportSettingsView: View {
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    CareIcon(name: "Stitch_qr_code_2", color: CareTheme.feeding, size: 32)
                    Text(L10n.text("Chưa có liên kết báo cáo")).font(CareFont.title3.bold())
                    Text(L10n.text("Phiên bản hiện tại cho phép tạo và chia sẻ PDF trên thiết bị. Tạo liên kết QR cần dịch vụ chia sẻ trực tuyến chưa được kết nối."))
                        .font(CareFont.body).foregroundStyle(CareTheme.secondary)
                }.padding(.vertical, 10)
                NavigationLink(L10n.text("Tạo báo cáo PDF")) { ShareReportView() }
            }
        }
        .navigationTitle(L10n.text("Báo cáo đã chia sẻ")).navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView().environment(BabyCareViewModel.preview()) }
}
