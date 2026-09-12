import SwiftUI
import PhotosUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

/// Stitch P — native view backed by the existing data provider.
struct BabyProfileView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var editingProfile = false
    @State private var addingMeasurement = false
    @State private var addingBaby = false
    @State private var editingHealth = false

    private var latestWeight: BodyMeasurement? {
        viewModel.measurements.filter { $0.weight != nil }.max { $0.date < $1.date }
    }
    private var latestHeight: BodyMeasurement? {
        viewModel.measurements.filter { $0.height != nil }.max { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            CareFormCard {
                VStack(spacing: 16) {
                    Button { editingProfile = true } label: {
                        ProfileAvatarView(name: viewModel.baby.name, imageData: viewModel.baby.avatarData, size: 88)
                            .overlay(alignment: .bottomTrailing) {
                                CareIcon(name: "Stitch_photo_camera", color: .white, size: 16)
                                    .padding(8).background(CareTheme.accent, in: Circle())
                            }
                    }.buttonStyle(.plain).accessibilityLabel("Đổi ảnh và chỉnh sửa hồ sơ bé")
                    Text(viewModel.baby.name).font(CareFont.title2.bold())
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { birthdayLabel; genderLabel }
                        VStack(spacing: 8) { birthdayLabel; genderLabel }
                    }
                    Button { editingProfile = true } label: {
                        HStack(spacing: 8) {
                            CareIcon(name: "Stitch_edit", color: CareTheme.text, size: 18)
                            Text("Chỉnh sửa thông tin hồ sơ").font(CareFont.subheadline.weight(.semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(CareActionStyle(color: CareTheme.text, outlined: true))
                    .accessibilityIdentifier("editBabyProfileButton")
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
            }

            CareFormCard {
                VStack(alignment: .leading, spacing: 16) {
                    CareSectionTitle(title: "Chỉ số thể chất mới nhất", subtitle: "Theo ngày đo của từng chỉ số")
                    HStack(alignment: .top, spacing: 12) {
                        metric("Cân nặng", value: latestWeight?.weight, unit: "kg", date: latestWeight?.date, icon: "Stitch_scale")
                        metric("Chiều dài", value: latestHeight?.height, unit: "cm", date: latestHeight?.date, icon: "Stitch_straighten")
                    }
                    Button { addingMeasurement = true } label: {
                        HStack {
                            CareIcon(name: "Stitch_add_circle", color: .white, size: 20)
                            Text("Thêm số đo mới").font(CareFont.headline)
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(CareActionStyle())
                }.padding(.vertical, 8)
                NavigationLink {
                    MeasurementHistoryView()
                } label: {
                    profileRow("Biểu đồ & lịch sử tăng trưởng", icon: "Stitch_query_stats", color: CareTheme.accent)
                }
            }

            CareFormCard(title: "Lưu ý Y tế & Chăm sóc") {
                Button { editingHealth = true } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        profileRow("Dị ứng & Phản ứng thuốc", icon: "Stitch_healing", color: CareTheme.medical)
                        Text(viewModel.baby.allergies.isEmpty ? "Chưa cung cấp thông tin dị ứng" : viewModel.baby.allergies)
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
                Button { editingHealth = true } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        profileRow("Thói quen & Lưu ý chăm sóc", icon: "Stitch_bedtime", color: CareTheme.routine)
                        Text(viewModel.baby.healthNotes.isEmpty ? "Thêm thói quen hoặc lời dặn chăm sóc bé." : viewModel.baby.healthNotes)
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
                LabeledContent("Nhóm máu", value: viewModel.baby.bloodType.isEmpty ? "Chưa rõ" : viewModel.baby.bloodType)
                    .font(CareFont.subheadline)
            }

            CareFormCard(title: "Bé trong gia đình · \(viewModel.babies.count) bé") {
                ForEach(viewModel.babies) { baby in
                    Button {
                        Task { await viewModel.send(.commit(.selectBaby(baby.id), message: "Đang xem bé \(baby.name)")) }
                    } label: {
                        HStack(spacing: 12) {
                            ProfileAvatarView(name: baby.name, imageData: baby.avatarData, size: 42)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(baby.name).font(CareFont.headline)
                                Text("\(profileAge(baby.birthDate)) · \(baby.gender.title)")
                                    .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                            }
                            Spacer(minLength: 4)
                            if baby.id == viewModel.baby.id {
                                CareIcon(name: "Stitch_check_circle", color: CareTheme.accent, size: 24)
                                    .accessibilityLabel("Đang chọn")
                            }
                        }.padding(12).background(baby.id == viewModel.baby.id ? CareTheme.accent.opacity(0.05) : CareTheme.background, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(baby.id == viewModel.baby.id ? CareTheme.accent.opacity(0.25) : CareTheme.border))
                    }.buttonStyle(.plain)
                }
                Button { addingBaby = true } label: {
                    profileRow("Thêm hồ sơ bé", icon: "Stitch_add_circle", color: CareTheme.accent)
                }.disabled(viewModel.babies.count >= CareDatabase.maximumBabies)
                Text("\(viewModel.babies.count)/4 hồ sơ bé").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle("Hồ sơ của bé")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    CareIcon(name: "Stitch_tune", color: CareTheme.accent, size: 22)
                }.accessibilityLabel("Cài đặt")
            }
        }
        .sheet(isPresented: $editingProfile) { NavigationStack { ProfileEditorView(profile: viewModel.baby) } }
        .sheet(isPresented: $editingHealth) { NavigationStack { ProfileHealthEditorView(profile: viewModel.baby) } }
        .sheet(isPresented: $addingMeasurement) { NavigationStack { MeasurementEntryView() } }
        .sheet(isPresented: $addingBaby) { NavigationStack { OnboardingView(isAddingBaby: true) } }
    }

    private var birthdayLabel: some View {
        Text("\(viewModel.baby.birthDate.careFormatted(date: .numeric, time: .omitted)) · \(profileAge(viewModel.baby.birthDate))")
            .font(CareFont.caption.weight(.medium)).foregroundStyle(CareTheme.accent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(CareTheme.accent.opacity(0.08), in: Capsule())
    }

    private var genderLabel: some View {
        Text(viewModel.baby.gender.title).font(CareFont.caption.weight(.medium)).foregroundStyle(CareTheme.medical)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(CareTheme.medicalBackground, in: Capsule())
    }

    private func metric(_ title: String, value: Double?, unit: String, date: Date?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                Spacer(minLength: 0)
                CareIcon(name: icon, color: CareTheme.accent, size: 19)
            }
            if let value {
                Text("\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)")
                    .font(CareFont.title2.bold())
            } else {
                Text("Chưa ghi nhận").font(CareFont.subheadline)
            }
            if let date { Text(date.careFormatted(date: .numeric, time: .omitted)).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(CareTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileEditorView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State var profile: BabyProfile
    @State private var photoLoadID: UUID?
    private var loadingPhoto: Bool { photoLoadID != nil }
    @State private var photo: PhotosPickerItem?
    @State private var photoError: String?

    private var latestAllowedBirthDate: Date {
        min(Date(), viewModel.activities.map(\.date).min() ?? Date(), viewModel.measurements.map(\.date).min() ?? Date())
    }

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $photo, matching: .images) {
                    VStack(spacing: 12) {
                        ProfileAvatarView(name: profile.name, imageData: profile.avatarData, size: 80)
                        HStack {
                            CareIcon(name: "Stitch_photo_camera", color: CareTheme.accent, size: 18)
                            Text("Chọn ảnh đại diện")
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                if profile.avatarData != nil {
                    Button("Dùng avatar chữ cái", role: .destructive) { profile.avatarData = nil; photo = nil }
                }
                if let photoError { Text(photoError).font(CareFont.footnote).foregroundStyle(CareTheme.medical) }
                TextField("Tên gọi ở nhà · Bắt buộc", text: $profile.name)
                DatePicker("Ngày sinh", selection: $profile.birthDate, in: ...latestAllowedBirthDate, displayedComponents: .date)
                Picker("Giới tính", selection: $profile.gender) {
                    ForEach(BabyGender.allCases) { Text($0.title).tag($0) }
                }
            } footer: { Text("Ngày sinh không được sau hoạt động hoặc số đo đã lưu.") }
        }
        .scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle("Sửa hồ sơ bé").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu", action: save).disabled(loadingPhoto || viewModel.state.isSaving || profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task(id: photo) {
            guard let selection = photo else { photoLoadID = nil; return }
            let loadID = UUID()
            photoLoadID = loadID
            defer { if photoLoadID == loadID { photoLoadID = nil } }
            do {
                let data = try await selection.loadTransferable(type: Data.self)
                guard !Task.isCancelled else { return }
                guard let data, let prepared = CareImageProcessor.jpeg(data, avatar: true) else {
                    photoError = "Không đọc được ảnh này. Hãy chọn ảnh khác."
                    return
                }
                profile.avatarData = prepared
                photoError = nil
            } catch {
                guard !Task.isCancelled else { return }
                photoError = "Chưa tải được ảnh. Hãy chọn lại."
            }
        }
    }

    private func save() {
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            guard await viewModel.send(.commit(.updateBaby(profile), message: "Đã cập nhật hồ sơ bé")) else { return }
            dismiss()
        }
    }
}

private struct ProfileHealthEditorView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State var profile: BabyProfile

    var body: some View {
        Form {
            Section("Dị ứng & Phản ứng thuốc") {
                TextField("Thông tin gia đình cung cấp", text: $profile.allergies, axis: .vertical).lineLimit(3...6)
            }
            Section("Thói quen & Lưu ý chăm sóc") {
                TextField("Thói quen, lời dặn hoặc thông tin cần lưu ý", text: $profile.healthNotes, axis: .vertical).lineLimit(4...8)
            }
            Section {
                TextField("Nhóm máu nếu biết", text: $profile.bloodType)
            } footer: { Text("Để trống thông tin chưa biết. Ghi chú do gia đình cung cấp không phải chẩn đoán.") }
        }
        .scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle("Lưu ý sức khỏe").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    Task {
                        guard await viewModel.send(.commit(.updateBaby(profile), message: "Đã cập nhật lưu ý sức khỏe")) else { return }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MeasurementHistoryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var addingMeasurement = false
    @State private var metric = "Cân nặng"
    @State private var selectedMeasurement: BodyMeasurement?
    private var sorted: [BodyMeasurement] { viewModel.measurements.sorted { $0.date > $1.date } }

    var body: some View {
        List {
            if sorted.isEmpty {
                ContentUnavailableView {
                    Text("Chưa có số đo")
                } description: {
                    Text("Thêm cân nặng hoặc chiều cao đầu tiên của bé.")
                } actions: {
                    Button("Thêm số đo") { addingMeasurement = true }.buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    Picker("Chỉ số", selection: $metric) {
                        Text("Cân nặng").tag("Cân nặng")
                        Text("Chiều cao").tag("Chiều cao")
                    }.pickerStyle(.segmented)
                    Chart(sorted.reversed()) { measurement in
                        if let value = metric == "Cân nặng" ? measurement.weight : measurement.height, value.isFinite {
                            LineMark(x: .value("Ngày", measurement.date), y: .value(metric, value))
                                .foregroundStyle(CareTheme.accent).interpolationMethod(.monotone)
                            PointMark(x: .value("Ngày", measurement.date), y: .value(metric, value))
                                .foregroundStyle(CareTheme.accent)
                        }
                    }.frame(height: 200).padding(.vertical, 8)
                        .accessibilityLabel("Biểu đồ \(metric). Các số đo có trong danh sách bên dưới.")
                }
                Section("Tất cả số đo") {
                    ForEach(sorted) { measurement in
                        Button { selectedMeasurement = measurement } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(measurement.date.careFormatted(date: .abbreviated, time: .shortened)).font(CareFont.headline)
                                Text(measurementDescription(measurement)).font(CareFont.body).foregroundStyle(CareTheme.accent)
                                if !measurement.notes.isEmpty { Text(measurement.notes).font(CareFont.footnote).foregroundStyle(CareTheme.secondary) }
                            }.padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityHint("Chạm để sửa số đo")
                    }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle("Lịch sử tăng trưởng").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Thêm") { addingMeasurement = true } } }
        .sheet(isPresented: $addingMeasurement) { NavigationStack { MeasurementEntryView() } }
        .sheet(item: $selectedMeasurement) { measurement in
            NavigationStack { MeasurementEntryView(measurement: measurement) }
        }
    }

    private func measurementDescription(_ item: BodyMeasurement) -> String {
        [item.weight.map { "\($0.formatted()) kg" }, item.height.map { "\($0.formatted()) cm" }, item.headCircumference.map { "Vòng đầu \($0.formatted()) cm" }]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

func profileRow(_ title: String, icon: String, color: Color) -> some View {
    HStack(spacing: 12) {
        CareIcon(name: icon, color: color, size: 22)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        Text(title).font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.text)
    }.padding(.vertical, 3)
}

#Preview {
    NavigationStack { BabyProfileView().environment(BabyCareViewModel.preview()) }
}
