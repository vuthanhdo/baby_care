import SwiftUI
import PhotosUI
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

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        ScrollView {
            // Open iPhone Duo / iPad: profile and growth beside health notes and the family's babies.
            CareColumns {
            CareFormCard {
                VStack(spacing: 16) {
                    Button { editingProfile = true } label: {
                        ProfileAvatarView(name: viewModel.baby.name, imageData: viewModel.baby.avatarData, size: 88)
                            .overlay(alignment: .bottomTrailing) {
                                CareIcon(name: "Stitch_photo_camera", color: .white, size: 16)
                                    .padding(8).background(CareTheme.accent, in: Circle())
                            }
                    }.buttonStyle(.plain).accessibilityLabel(L10n.text("Đổi ảnh và chỉnh sửa hồ sơ bé"))
                    Text(viewModel.baby.name).font(CareFont.title2.bold())
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { birthdayLabel; genderLabel }
                        VStack(spacing: 8) { birthdayLabel; genderLabel }
                    }
                    Button { editingProfile = true } label: {
                        HStack(spacing: 8) {
                            CareIcon(name: "Stitch_edit", color: CareTheme.text, size: 18)
                            Text(L10n.text("Chỉnh sửa thông tin hồ sơ")).font(CareFont.subheadline.weight(.semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(CareActionStyle(color: CareTheme.text, outlined: true))
                    .accessibilityIdentifier("editBabyProfileButton")
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
            }

            CareFormCard {
                VStack(alignment: .leading, spacing: 16) {
                    CareSectionTitle(title: L10n.text("Chỉ số thể chất mới nhất"), subtitle: L10n.text("Theo ngày đo của từng chỉ số"))
                    HStack(alignment: .top, spacing: 12) {
                        metric(L10n.text("Cân nặng"), value: latestWeight?.weight, unit: "kg", date: latestWeight?.date, icon: "Stitch_scale")
                        metric(L10n.text("Chiều dài"), value: latestHeight?.height, unit: "cm", date: latestHeight?.date, icon: "Stitch_straighten")
                    }
                    Button { addingMeasurement = true } label: {
                        HStack {
                            CareIcon(name: "Stitch_add_circle", color: .white, size: 20)
                            Text(L10n.text("Thêm số đo mới")).font(CareFont.headline)
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(CareActionStyle())
                }.padding(.vertical, 8)
                NavigationLink {
                    MeasurementHistoryView()
                } label: {
                    profileRow(L10n.text("Biểu đồ & lịch sử tăng trưởng"), icon: "Stitch_query_stats", color: CareTheme.accent)
                }
            }

            CareFormCard {
                NavigationLink {
                    VaccinationHistoryView(babyID: viewModel.baby.id)
                } label: {
                    profileRow(L10n.text("Lịch sử tiêm chủng"), icon: "Stitch_local_hospital", color: CareTheme.medical)
                }.accessibilityIdentifier("vaccinationHistoryLink")
            }

            } trailing: {
            CareFormCard(title: L10n.text("Lưu ý Y tế & Chăm sóc")) {
                Button { editingHealth = true } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        profileRow(L10n.text("Dị ứng & Phản ứng thuốc"), icon: "Stitch_healing", color: CareTheme.medical)
                        Text(viewModel.baby.allergies.isEmpty ? L10n.text("Chưa cung cấp thông tin dị ứng") : AllergyNote.display(viewModel.baby.allergies))
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
                Button { editingHealth = true } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        profileRow(L10n.text("Tiền sử bệnh lý"), icon: "Stitch_clinical_notes", color: CareTheme.medical)
                        Text(viewModel.baby.medicalHistory.isEmpty ? L10n.text("Chưa cung cấp tiền sử bệnh") : viewModel.baby.medicalHistory)
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain).accessibilityIdentifier("profile.medicalHistory")
                Button { editingHealth = true } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        profileRow(L10n.text("Thói quen & Lưu ý chăm sóc"), icon: "Stitch_bedtime", color: CareTheme.routine)
                        Text(viewModel.baby.healthNotes.isEmpty ? L10n.text("Thêm thói quen hoặc lời dặn chăm sóc bé.") : viewModel.baby.healthNotes)
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
                LabeledContent(L10n.text("Nhóm máu"), value: L10n.text(viewModel.baby.bloodType.isEmpty ? "Chưa rõ" : viewModel.baby.bloodType))
                    .font(CareFont.subheadline)
            }

            CareFormCard(title: L10n.count(viewModel.babies.count, one: "Bé trong gia đình · 1 bé", many: "Bé trong gia đình · {0} bé")) {
                ForEach(viewModel.babies) { baby in
                    Button {
                        Task { await viewModel.send(.commit(.selectBaby(baby.id), message: L10n.text("Đang xem bé {0}", "\(baby.name)"))) }
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
                                    .accessibilityLabel(L10n.text("Đang chọn"))
                            }
                        }.padding(12).background(baby.id == viewModel.baby.id ? CareTheme.accent.opacity(0.05) : CareTheme.background, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(baby.id == viewModel.baby.id ? CareTheme.accent.opacity(0.25) : CareTheme.border))
                    }.buttonStyle(.plain)
                }
                Button { addingBaby = true } label: {
                    profileRow(L10n.text("Thêm hồ sơ bé"), icon: "Stitch_add_circle", color: CareTheme.accent)
                }.disabled(viewModel.babies.count >= CareDatabase.maximumBabies)
                Text(L10n.text("{0}/4 hồ sơ bé", "\(viewModel.babies.count)")).font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle(L10n.text("Hồ sơ của bé"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    CareIcon(name: "Stitch_tune", color: CareTheme.accent, size: 22)
                }.accessibilityLabel(L10n.text("Cài đặt"))
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
                Text("\(value.formatted(.number.precision(.fractionLength(0...2)).locale(AppLanguage.current.locale))) \(unit)")
                    .font(CareFont.title2.bold())
            } else {
                Text(L10n.text("Chưa ghi nhận")).font(CareFont.subheadline)
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
        min(Date(), viewModel.activities.map(\.date).min() ?? Date(), viewModel.measurements.map(\.date).min() ?? Date(), viewModel.vaccinations.map(\.date).min() ?? Date())
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Form {
            Section {
                PhotosPicker(selection: $photo, matching: .images) {
                    VStack(spacing: 12) {
                        ProfileAvatarView(name: profile.name, imageData: profile.avatarData, size: 80)
                        HStack {
                            CareIcon(name: "Stitch_photo_camera", color: CareTheme.accent, size: 18)
                            Text(L10n.text("Chọn ảnh đại diện"))
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                if profile.avatarData != nil {
                    Button(L10n.text("Dùng avatar chữ cái"), role: .destructive) { profile.avatarData = nil; photo = nil }
                }
                if let photoError { Text(photoError).font(CareFont.footnote).foregroundStyle(CareTheme.medical) }
                TextField(L10n.text("Tên gọi ở nhà · Bắt buộc"), text: $profile.name)
                DatePicker(L10n.text("Ngày sinh"), selection: $profile.birthDate, in: ...latestAllowedBirthDate, displayedComponents: .date)
                Picker(L10n.text("Giới tính"), selection: $profile.gender) {
                    ForEach(BabyGender.allCases) { Text($0.title).tag($0) }
                }
            } footer: { Text(L10n.text("Ngày sinh không được sau hoạt động hoặc số đo đã lưu.")) }
        }
        .scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle(L10n.text("Sửa hồ sơ bé")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) { HStack { if viewModel.state.isSaving { ProgressView() }; Text(L10n.text("Lưu")) } }.disabled(viewModel.state.isSaving).disabled(loadingPhoto || viewModel.state.isSaving || profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    photoError = L10n.text("Không đọc được ảnh này. Hãy chọn ảnh khác.")
                    return
                }
                profile.avatarData = prepared
                photoError = nil
            } catch {
                guard !Task.isCancelled else { return }
                photoError = L10n.text("Chưa tải được ảnh. Hãy chọn lại.")
            }
        }
    }

    private func save() {
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            guard await viewModel.send(.commit(.updateBaby(profile), message: L10n.text("Đã cập nhật hồ sơ bé"))) else { return }
            dismiss()
        }
    }
}

private struct ProfileHealthEditorView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var profile: BabyProfile
    @State private var allergies: [EditableAllergy]

    private struct EditableAllergy: Identifiable {
        let id = UUID()
        var note = AllergyNote()
    }

    init(profile: BabyProfile) {
        _profile = State(initialValue: profile)
        _allergies = State(initialValue: AllergyNote.list(profile.allergies).map { EditableAllergy(note: $0) })
    }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Form {
            Section {
                ForEach($allergies) { $item in
                    VStack(alignment: .leading, spacing: 10) {
                        AllergyNoteFields(note: $item.note)
                        Button(L10n.text("Xóa dị ứng này"), role: .destructive) { allergies.removeAll { $0.id == item.id } }
                            .buttonStyle(.borderless).font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                    }.padding(.vertical, 6)
                }
                Button(L10n.text("+ Thêm dị ứng")) { allergies.append(EditableAllergy()) }
                    .buttonStyle(.borderless).foregroundStyle(CareTheme.accent).accessibilityIdentifier("allergy.add")
            } header: {
                Text(L10n.text("Dị ứng & Phản ứng thuốc"))
            } footer: {
                Text(L10n.text("Mỗi dị ứng gồm tên chất, mức độ phản ứng và độ chắc chắn."))
            }
            Section {
                TextField(L10n.text("Bệnh đã mắc, phẫu thuật, nằm viện hoặc bệnh mạn tính"), text: $profile.medicalHistory, axis: .vertical).lineLimit(3...8)
                    .accessibilityIdentifier("medicalHistoryField")
            } header: { Text(L10n.text("Tiền sử bệnh lý")) }
            Section(L10n.text("Thói quen & Lưu ý chăm sóc")) {
                TextField(L10n.text("Thói quen, lời dặn hoặc thông tin cần lưu ý"), text: $profile.healthNotes, axis: .vertical).lineLimit(4...8)
            }
            Section {
                TextField(L10n.text("Nhóm máu nếu biết"), text: $profile.bloodType)
            } footer: { Text(L10n.text("Để trống thông tin chưa biết. Ghi chú do gia đình cung cấp không phải chẩn đoán.")) }
        }
        .scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle(L10n.text("Lưu ý sức khỏe")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Hủy")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                CareAsyncButton(L10n.text("Lưu")) {
                        var profile = profile
                        profile.allergies = AllergyNote.text(allergies.map(\.note))
                        profile.medicalHistory = profile.medicalHistory.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard await viewModel.send(.commit(.updateBaby(profile), message: L10n.text("Đã cập nhật lưu ý sức khỏe"))) else { return }
                        dismiss()
                }.disabled(viewModel.state.isSaving)
            }
        }
    }
}

struct MeasurementHistoryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var addingMeasurement = false
    @State private var metric: GrowthMetric = .weight
    @State private var selectedMeasurement: BodyMeasurement?
    private var sorted: [BodyMeasurement] { viewModel.measurements.sorted { $0.date > $1.date } }

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        List {
            if sorted.isEmpty {
                ContentUnavailableView {
                    Text(L10n.text("Chưa có số đo"))
                } description: {
                    Text(L10n.text("Thêm cân nặng hoặc chiều cao đầu tiên của bé."))
                } actions: {
                    Button(L10n.text("Thêm số đo")) { addingMeasurement = true }.buttonStyle(.borderedProminent)
                }
            } else {
                Section {
                    Picker(L10n.text("Chỉ số"), selection: $metric) {
                        ForEach(GrowthMetric.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
                    }.pickerStyle(.segmented)
                    GrowthChartView(measurements: sorted, metric: metric, profile: viewModel.baby) { _ in EmptyView() }
                        .padding(.vertical, 8)
                }
                Section(L10n.text("Tất cả số đo")) {
                    ForEach(sorted) { measurement in
                        Button { selectedMeasurement = measurement } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(measurement.date.careFormatted(date: .abbreviated, time: .shortened)).font(CareFont.headline)
                                Text(measurementDescription(measurement)).font(CareFont.body).foregroundStyle(CareTheme.accent)
                                if !measurement.notes.isEmpty { Text(measurement.notes).font(CareFont.footnote).foregroundStyle(CareTheme.secondary) }
                            }.padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityHint(L10n.text("Chạm để sửa số đo"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CareTheme.background)
        .navigationTitle(L10n.text("Lịch sử tăng trưởng")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Thêm")) { addingMeasurement = true } } }
        .sheet(isPresented: $addingMeasurement) { NavigationStack { MeasurementEntryView() } }
        .sheet(item: $selectedMeasurement) { measurement in
            NavigationStack { MeasurementEntryView(measurement: measurement) }
        }
    }

    private func measurementDescription(_ item: BodyMeasurement) -> String {
        [item.weight.map { "\($0.formatted(.number.locale(AppLanguage.current.locale))) kg" }, item.height.map { "\($0.formatted(.number.locale(AppLanguage.current.locale))) cm" }, item.headCircumference.map { L10n.text("Vòng đầu {0} cm", "\($0.formatted(.number.locale(AppLanguage.current.locale)))") }]
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
