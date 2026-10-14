import SwiftUI
import PhotosUI
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
    @State private var photo: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var photoError: String?
    @State private var photoLoadID: UUID?
    private var hasDraft: Bool { !validName.isEmpty || avatarData != nil || photo != nil }


    private var validName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            VStack(spacing: 20) {
            Group {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        CareIcon(name: "Stitch_favorite", color: .white, size: 18)
                            .frame(width: 32, height: 32).background(CareTheme.accent, in: .rect(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("BÉ KHỎE – BỐ MẸ AN TÂM")).font(CareFont.caption).bold().foregroundStyle(CareTheme.accent)
                            Text(L10n.text("Chăm sóc con khoa học & thảnh thơi")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        }
                    }
                    (isAddingBaby ? Text(L10n.text("Thêm một hồ sơ bé")) : Text("\(Text(L10n.text("Ghi nhanh để chăm bé ")))\(Text(L10n.text("an tâm hơn")).foregroundColor(CareTheme.accent).underline(color: CareTheme.accent.opacity(0.3)))"))
                        .font(.custom("BeVietnamPro-Bold", size: 26, relativeTo: .title)).foregroundStyle(CareTheme.text)
                    Text(L10n.text("Tạo hồ sơ cho bé để bắt đầu theo dõi cữ sữa, giấc ngủ và nhiệt độ."))
                        .font(CareFont.callout).foregroundStyle(CareTheme.secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            EntryFormCard(cornerRadius: 20) {
                VStack(spacing: 10) {
                    PhotosPicker(selection: $photo, matching: .images) {
                        ProfileAvatarView(name: validName, imageData: avatarData, size: 80)
                            .overlay(alignment: .bottomTrailing) {
                                CareIcon(name: "Stitch_photo_camera", color: .white, size: 16)
                                    .frame(width: 30, height: 30).background(CareTheme.accent, in: .circle)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            }
                    }.buttonStyle(.plain).disabled(viewModel.state.isSaving)
                        .accessibilityLabel(avatarData == nil ? L10n.text("Chọn ảnh đại diện") : L10n.text("Đổi ảnh đại diện"))
                        .accessibilityIdentifier("babyAvatarPicker")
                    if photoLoadID != nil {
                        ProgressView(L10n.text("Đang xử lý ảnh…")).font(CareFont.footnote)
                    } else {
                        Text(avatarData == nil ? L10n.text("Chọn ảnh hoặc dùng avatar chữ cái theo tên") : L10n.text("Ảnh đại diện của bé"))
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                    if avatarData != nil {
                        Button(L10n.text("Dùng avatar chữ cái")) { photo = nil; avatarData = nil; photoError = nil }
                            .font(CareFont.footnote).disabled(viewModel.state.isSaving)
                    }
                    if let photoError { Text(photoError).font(CareFont.footnote).foregroundStyle(CareTheme.medical) }

                }
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 8) {
                    requiredLabel(L10n.text("Tên gọi ở nhà của bé"))
                    TextField(L10n.text("Ví dụ: Bé An"), text: $name)
                        .textContentType(.nickname)
                        .textFieldStyle(EntryInputStyle(shaded: true))
                        .overlay(alignment: .trailing) {
                            if !validName.isEmpty { CareIcon(name: "Stitch_check_circle", color: CareTheme.accent, size: 18).padding(.trailing, 12).allowsHitTesting(false) }
                        }
                        .accessibilityIdentifier("babyNameField")
                    Text(L10n.text("Dùng để hiển thị trong lời nhắc và nhật ký của bé."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }.padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 8) {
                    requiredLabel(L10n.text("Ngày sinh của bé"))
                    HStack {
                        CareIcon(name: "Stitch_calendar_month", color: CareTheme.secondary, size: 20)
                        DatePicker(L10n.text("Ngày sinh"), selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10).frame(maxWidth: .infinity, minHeight: 48)
                        .background(CareTheme.background, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CareTheme.border))
                    Text(L10n.text("Hiện tại: {0}", "\(profileAge(birthDate))"))
                        .font(CareFont.caption).foregroundStyle(CareTheme.accent)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.text("Giới tính của bé")).font(CareFont.callout.weight(.semibold))
                        Spacer()
                        Text(L10n.text("Tùy chọn")).font(CareFont.caption2).foregroundStyle(CareTheme.secondary)
                    }
                    HStack(spacing: 10) {
                        genderButton(.girl, title: L10n.text("👧 Bé gái"))
                        genderButton(.boy, title: L10n.text("👦 Bé trai"))
                        genderButton(.unspecified, title: L10n.text("Để sau"))
                    }
                }
            }

            Group {
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "Stitch_shield", color: CareTheme.accent, size: 20)
                    Text(viewModel.state.storage == .device
                         ? L10n.text("Dữ liệu của bé được lưu trên thiết bị. Bạn có thể đăng nhập trong Cài đặt khi cần dùng cloud.")
                         : L10n.text("Tài khoản của bạn có thể lưu tối đa 4 hồ sơ bé."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle(isAddingBaby ? L10n.text("Thêm bé") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isAddingBaby ? .visible : .hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                CarePrimaryButton(title: isAddingBaby ? L10n.text("Tạo hồ sơ bé") : L10n.text("Tiếp tục"), icon: "Stitch_arrow_forward", isLoading: viewModel.state.isSaving) {
                    createProfile()
                }
                    .disabled(validName.isEmpty || photoLoadID != nil || viewModel.state.isSaving || viewModel.babies.count >= CareDatabase.maximumBabies)
                    .accessibilityIdentifier("createBabyButton")
                Text(viewModel.babies.count >= CareDatabase.maximumBabies ? L10n.text("Bạn đã có đủ 4 hồ sơ bé.") : validName.isEmpty ? L10n.text("Nhập tên bé để bắt đầu.") : L10n.text("Có thể chỉnh sửa hoặc thêm bé trong Hồ sơ bé."))
                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
            }
            .padding().background(CareTheme.background)
        }
        .toolbar {
            if isAddingBaby {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Hủy")) { if !hasDraft { dismiss() } else { confirmDiscard = true } }
                }
            }
        }
        .interactiveDismissDisabled(isAddingBaby && hasDraft)
        .task(id: photo) {
            guard let selection = photo else { photoLoadID = nil; return }
            let loadID = UUID()
            photoLoadID = loadID
            photoError = nil
            defer { if photoLoadID == loadID { photoLoadID = nil } }
            do {
                let data = try await selection.loadTransferable(type: Data.self)
                guard !Task.isCancelled else { return }
                guard let data, let prepared = CareImageProcessor.jpeg(data, avatar: true) else {
                    photoError = L10n.text("Không đọc được ảnh này. Hãy chọn ảnh khác.")
                    return
                }
                avatarData = prepared
            } catch {
                guard !Task.isCancelled else { return }
                photoError = L10n.text("Chưa tải được ảnh. Hãy kiểm tra mạng hoặc chọn lại.")
            }
        }
        .confirmationDialog(L10n.text("Bỏ nội dung chưa lưu?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L10n.text("Bỏ nội dung"), role: .destructive) { dismiss() }
            Button(L10n.text("Tiếp tục nhập"), role: .cancel) { }
        }
    }

    private func requiredLabel(_ title: String) -> some View {
        HStack {
            Text("\(Text(title))\(Text(" *").foregroundColor(CareTheme.medical))").font(CareFont.callout.weight(.semibold))
            Spacer(minLength: 4)
            Text(L10n.text("Bắt buộc")).font(CareFont.caption2).foregroundStyle(CareTheme.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3).background(CareTheme.background, in: .capsule)
        }
    }
    private func genderButton(_ value: BabyGender, title: String) -> some View {
        let selected = gender == value
        let color = value == .girl ? CareTheme.medical : value == .boy ? CareTheme.feeding : CareTheme.accent
        return Button { gender = value } label: {
            Text(title).font(CareFont.footnote.weight(.semibold))
                .foregroundStyle(selected ? color : CareTheme.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? color.opacity(0.08) : CareTheme.background, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? color : CareTheme.border, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func createProfile() {
        guard photoLoadID == nil, !viewModel.state.isSaving else { return }
        let baby = BabyProfile(id: profileID, name: validName, birthDate: Calendar.current.startOfDay(for: birthDate), gender: gender, avatarData: avatarData)
        Task {
            guard await viewModel.send(.commit(.createBaby(baby), message: L10n.text("Đã tạo hồ sơ bé {0}", "\(validName)"))) else { return }
            if isAddingBaby { dismiss() }
        }
    }
}

struct ProfileAvatarView: View {
    let name: String
    var imageData: Data? = nil
    var size: CGFloat = 76

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
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
        .accessibilityLabel(L10n.text("Ảnh đại diện {0}", "\(name)"))
    }

    private var initial: some View {
        Text(name.split(separator: " ").last?.prefix(1).uppercased() ?? "B")
            .font(.custom("BeVietnamPro-SemiBold", size: size * 0.38, relativeTo: .title2))
            .foregroundStyle(CareTheme.accent)
    }
}

func profileAge(_ birthDate: Date, at date: Date = Date()) -> String {
    BabyProfile.ageText(from: birthDate, at: date)
}

#Preview {
    NavigationStack { OnboardingView().environment(BabyCareViewModel.preview()) }
}
