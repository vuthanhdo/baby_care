import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Stitch A — native view backed by the existing data provider.
struct OnboardingView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    var isAddingBaby = false
    @State private var profileID = UUID()
    @State private var name = ""
    @State private var birthDate = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var confirmDiscard = false

    private var validName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            Group {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        CareBrandView(size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BÉ KHỎE – BỐ MẸ AN TÂM").font(CareFont.caption).bold().foregroundStyle(CareTheme.accent)
                            Text("Chăm sóc con khoa học & thảnh thơi").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                    }
                    Text(isAddingBaby ? "Thêm một hồ sơ bé" : "Ghi nhanh để chăm bé an tâm hơn")
                        .font(CareFont.largeTitle).bold().foregroundStyle(CareTheme.text)
                    Text("Tạo hồ sơ cho bé để bắt đầu theo dõi cữ sữa, giấc ngủ và nhiệt độ.")
                        .font(CareFont.body).foregroundStyle(CareTheme.secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            CareFormCard {
                VStack(spacing: 10) {
                    ProfileAvatarView(name: validName, size: 76)
                    Text("Avatar chữ cái tự động theo tên").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tên gọi ở nhà của bé · Bắt buộc").font(CareFont.headline)
                    TextField("Ví dụ: Bé An", text: $name)
                        .textContentType(.nickname)
                        .accessibilityIdentifier("babyNameField")
                    Text("Dùng để hiển thị trong lời nhắc và nhật ký của bé.")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }.padding(.vertical, 4)
                DatePicker("Ngày sinh · Bắt buộc", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                Text("Hiện tại: \(profileAge(birthDate))")
                    .font(CareFont.footnote).foregroundStyle(CareTheme.accent)
                Picker("Giới tính · Tùy chọn", selection: $gender) {
                    Text(BabyGender.girl.title).tag(BabyGender.girl)
                    Text(BabyGender.boy.title).tag(BabyGender.boy)
                    Text("Để sau").tag(BabyGender.unspecified)
                }
                .pickerStyle(.segmented)
            }

            CareFormCard {
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "ProfileShield", color: CareTheme.accent, size: 20)
                    Text(viewModel.state.storage == .device
                         ? "Dữ liệu của bé được lưu trên thiết bị. Bạn có thể đăng nhập trong Cài đặt khi cần dùng cloud."
                         : "Hồ sơ bé được lưu vào gia đình đang chọn trên tài khoản của bạn.")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .textFieldStyle(CareInputStyle())
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle(isAddingBaby ? "Thêm bé" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                CarePrimaryButton(title: isAddingBaby ? "Tạo hồ sơ bé" : "Bắt đầu ghi nhận", action: createProfile)
                    .disabled(validName.isEmpty)
                    .accessibilityIdentifier("createBabyButton")
                Text(validName.isEmpty ? "Nhập tên bé để bắt đầu." : "Có thể chỉnh sửa hoặc thêm bé trong Hồ sơ bé.")
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
            }
            .padding().background(CareTheme.background)
        }
        .toolbar {
            if isAddingBaby {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { if validName.isEmpty { dismiss() } else { confirmDiscard = true } }
                }
            }
        }
        .interactiveDismissDisabled(isAddingBaby && !validName.isEmpty)
        .confirmationDialog("Bỏ nội dung chưa lưu?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Bỏ nội dung", role: .destructive) { dismiss() }
            Button("Tiếp tục nhập", role: .cancel) { }
        }
    }

    private func createProfile() {
        let baby = BabyProfile(id: profileID, name: validName, birthDate: Calendar.current.startOfDay(for: birthDate), gender: gender)
        Task {
            guard await viewModel.send(.commit(.createBaby(baby), message: "Đã tạo hồ sơ bé \(validName)")) else { return }
            if isAddingBaby { dismiss() }
        }
    }
}

struct ProfileAvatarView: View {
    let name: String
    var imageData: Data? = nil
    var size: CGFloat = 76

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let imageData, let image = CareImageProcessor.thumbnail(imageData, maximumPixels: 400) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { initial }
            #else
            initial
            #endif
        }
        .frame(width: size, height: size)
        .background(CareTheme.accent.opacity(0.12), in: Circle())
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        .accessibilityLabel("Ảnh đại diện \(name)")
    }

    private var initial: some View {
        Text(name.split(separator: " ").last?.prefix(1).uppercased() ?? "B")
            .font(.custom("BeVietnamPro-SemiBold", size: size * 0.38, relativeTo: .title2))
            .foregroundStyle(CareTheme.accent)
    }
}

func profileAge(_ birthDate: Date, at date: Date = Date()) -> String {
    let components = Calendar.current.dateComponents([.month, .day], from: birthDate, to: date)
    let months = max(0, components.month ?? 0)
    if months >= 24 { return "\(months / 12) tuổi \(months % 12) tháng" }
    if months == 0 { return "\(max(0, components.day ?? 0)) ngày tuổi" }
    return "\(months) tháng tuổi"
}

#Preview {
    NavigationStack { OnboardingView().environment(BabyCareViewModel.preview()) }
}
