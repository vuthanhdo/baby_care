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
        switch textSize { case "large": "Lớn"; case "largest": "Rất lớn"; default: "Theo hệ thống iOS" }
    }

    var body: some View {
        List {
            Section {
                Text("Tùy chỉnh ứng dụng & dữ liệu của \(viewModel.baby.name)")
                    .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    .listRowBackground(Color.clear)
            }
            Section("Trải nghiệm & Hiển thị") {
                Button { showingTextSize = true } label: {
                    settingsRow("Cỡ chữ", subtitle: textSizeTitle, icon: "ProfileTextSize", color: CareTheme.accent)
                }.buttonStyle(.plain)
                Toggle(isOn: $habitSuggestions) {
                    settingsRow("Gợi ý theo thói quen", subtitle: "Gợi ý từ lần ghi gần đây; lịch đã đặt vẫn được giữ.", icon: "ProfileSparkles", color: CareTheme.routine)
                }
                settingsRow("Đơn vị đo", subtitle: "°C, kg, cm, ml · Hệ đo lường tiêu chuẩn Việt Nam", icon: "ProfileUnits", color: CareTheme.feeding)
            }

            Section("Theo dõi & Nhắc nhở") {
                NavigationLink { IllnessTrackingView() } label: {
                    settingsRow("Lịch nhắc thuốc", subtitle: "Kiểm tra lịch đã nhập cho bé", icon: "ProfileReminder", color: CareTheme.medical)
                }
                Button { showingPermissions = true } label: {
                    settingsRow("Quyền thông báo & Mic", subtitle: "Xem trạng thái quyền trên thiết bị", icon: "ProfileNotifications", color: CareTheme.accent)
                }.buttonStyle(.plain)
            }

            CareAccountSection()

            Section("Dữ liệu & Báo cáo") {
                NavigationLink { SharedReportSettingsView() } label: {
                    settingsRow("Liên kết báo cáo đã chia sẻ", subtitle: "Báo cáo PDF trên thiết bị", icon: "ProfileQR", color: CareTheme.feeding)
                }
                Button { showingStorage = true } label: {
                    settingsRow(viewModel.state.storage == .device ? "Bộ nhớ trên thiết bị" : "Dữ liệu cloud & cache", subtitle: "\(viewModel.activities.count) hoạt động · \(viewModel.measurements.count) số đo của bé", icon: "ProfileStorage", color: CareTheme.accent)
                }.buttonStyle(.plain)
            }

            Section("Hướng dẫn & Giới thiệu") {
                Button { showingGuide = true } label: {
                    settingsRow("Hướng dẫn sử dụng 4 bước", subtitle: "Ghi nhanh, Tìm lại, Lịch thuốc, Chia sẻ", icon: "ProfileGuide", color: CareTheme.accent)
                }.buttonStyle(.plain)
                Button { showingAbout = true } label: {
                    HStack(spacing: 13) {
                        CareBrandView(size: 44)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Về ứng dụng Bé Khỏe").font(CareFont.subheadline.weight(.semibold))
                            Text("Phiên bản \(appVersion)").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                        }
                    }.padding(.vertical, 5)
                }.buttonStyle(.plain)
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "ProfileMedicalInfo", color: CareTheme.medical, size: 18)
                    Text("Dữ liệu dùng để ghi nhận và trao đổi khi chăm sóc bé, không thay thế chẩn đoán hoặc chỉ định của nhân viên y tế.")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                }.padding(.vertical, 6).listRowBackground(CareTheme.medicalBackground)
            }

            Section {
                Text("Thiết kế vì sự an tâm của Bố Mẹ · Bé Khỏe")
                    .font(CareFont.caption).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: habitSuggestions) { _, _ in Task { await viewModel.send(.showMessage("Đã lưu cài đặt gợi ý")) } }
        .sheet(isPresented: $showingTextSize) {
            NavigationStack {
                Form {
                    Section {
                        Picker("Cỡ chữ", selection: $textSize) {
                            Text("Theo thiết bị").tag("system")
                            Text("Lớn").tag("large")
                            Text("Rất lớn").tag("largest")
                        }.pickerStyle(.inline)
                    }
                    Section("Xem trước") {
                        Text("Ghi nhanh để chăm bé an tâm hơn").font(CareFont.title2.bold())
                        Text("Tên, thời gian và nội dung được hiển thị rõ ràng trong nhật ký.").font(CareFont.body)
                    }
                }
                .navigationTitle("Cỡ chữ").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { showingTextSize = false } } }
                .dynamicTypeSize(textSize == "largest" ? .accessibility1 : textSize == "large" ? .xxxLarge : .large)
                .onChange(of: textSize) { _, _ in Task { await viewModel.send(.showMessage("Đã đổi cỡ chữ")) } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingPermissions) { NavigationStack { ProfilePermissionsView() } }
        .sheet(isPresented: $showingGuide) { NavigationStack { ProfileGuideView() } }
        .sheet(isPresented: $showingStorage) {
            NavigationStack {
                Form {
                    Section("Bé \(viewModel.baby.name)") {
                        LabeledContent("Hoạt động", value: "\(viewModel.activities.count)")
                        LabeledContent("Số đo cơ thể", value: "\(viewModel.measurements.count)")
                    }
                    Section {
                        if viewModel.state.storage == .device {
                            Text("Hồ sơ, nhật ký và số đo được lưu trên thiết bị này. Dữ liệu có thể mất khi xóa ứng dụng. Đăng nhập cloud không tự tải dữ liệu cũ lên.")
                        } else {
                            Text(viewModel.state.storage.message ?? "Dữ liệu đã được server xác nhận và có cache SwiftData riêng cho tài khoản, gia đình này. Khi offline, thay đổi được lưu trên máy và tự đồng bộ khi có mạng.")
                        }
                        NavigationLink("Tạo báo cáo PDF") { ShareReportView() }
                    }
                }
                .navigationTitle("Dữ liệu trên thiết bị").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { showingStorage = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAbout) {
            NavigationStack {
                Form {
                    Section {
                        Text("Bé Khỏe – Bố Mẹ An Tâm").font(CareFont.title2.bold())
                        LabeledContent("Phiên bản", value: appVersion)
                        Text("Ghi nhanh, tìm lại dễ dàng và theo dõi thông tin chăm sóc bé trong một ứng dụng.")
                    }
                    Section {
                        Text("Ứng dụng ghi nhận dữ liệu do gia đình cung cấp. Không tự chẩn đoán, kê đơn hoặc tính liều thuốc.")
                        Text("Bạn có thể dùng SwiftData trên thiết bị hoặc đăng nhập email để dùng dữ liệu cloud. Hai kho dữ liệu được giữ riêng cho tới khi bạn chủ động nhập dữ liệu.")
                    }
                }
                .navigationTitle("Về ứng dụng").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { showingAbout = false } } }
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
    @State private var microphone = "Đang kiểm tra…"
    @State private var notifications = "Đang kiểm tra…"

    var body: some View {
        Form {
            Section {
                LabeledContent("Micrô", value: microphone)
                LabeledContent("Thông báo", value: notifications)
            } footer: { Text("Ứng dụng chỉ yêu cầu quyền khi bạn dùng tính năng tương ứng.") }
            #if canImport(UIKit)
            Section {
                Button("Mở cài đặt thiết bị") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            #endif
        }
        .navigationTitle("Quyền truy cập").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { dismiss() } } }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted: microphone = "Đã cho phép"
        case .denied: microphone = "Đã từ chối"
        case .undetermined: microphone = "Chưa yêu cầu"
        @unknown default: microphone = "Chưa xác định"
        }
        #else
        microphone = "Kiểm tra trong cài đặt thiết bị"
        #endif
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notifications = "Đã cho phép"
        case .denied: notifications = "Đã từ chối"
        case .notDetermined: notifications = "Chưa yêu cầu"
        @unknown default: notifications = "Chưa xác định"
        }
    }
}

private struct ProfileGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            DisclosureGroup("1. Ghi nhanh") {
                Text("Chọn Y tế, Ăn uống hoặc Sinh hoạt; chọn hoạt động; kiểm tra dữ liệu rồi bấm Lưu. Thời điểm mặc định là hiện tại. Nội dung giọng nói cần xem lại trước khi lưu.")
            }
            DisclosureGroup("2. Tìm lại") {
                Text("Mở Nhật ký để tìm theo từ khóa, ngày hoặc nhóm hoạt động. Chạm một bản ghi để xem chi tiết và chỉnh sửa.")
            }
            DisclosureGroup("3. Theo dõi thuốc") {
                Text("Nhập lịch từ hướng dẫn bạn đang có và kiểm tra trước khi ghi đã dùng. Lời nhắc không tự tạo bản ghi và không thay thế chỉ định liều thuốc.")
            }
            DisclosureGroup("4. Chia sẻ báo cáo") {
                Text("Trong Thống kê, chọn Chia sẻ báo cáo, chọn thời gian và nội dung, xem trước rồi xuất PDF. Báo cáo phản ánh dữ liệu tại thời điểm tạo.")
            }
        }
        .navigationTitle("Hướng dẫn sử dụng").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { dismiss() } } }
    }
}

private struct SharedReportSettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    CareIcon(name: "ProfileQR", color: CareTheme.feeding, size: 32)
                    Text("Chưa có liên kết báo cáo").font(CareFont.title3.bold())
                    Text("Phiên bản hiện tại cho phép tạo và chia sẻ PDF trên thiết bị. Tạo liên kết QR cần dịch vụ chia sẻ trực tuyến chưa được kết nối.")
                        .font(CareFont.body).foregroundStyle(CareTheme.secondary)
                }.padding(.vertical, 10)
                NavigationLink("Tạo báo cáo PDF") { ShareReportView() }
            }
        }
        .navigationTitle("Báo cáo đã chia sẻ").navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView().environment(BabyCareViewModel.preview()) }
}
