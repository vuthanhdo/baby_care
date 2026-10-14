import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Stitch F — native view backed by the existing data provider.
struct ActivityFormView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let kind: ActivityKind
    let activity: CareActivity?
    var completingReminderID: UUID?
    var onSave: ((CareActivity) -> Void)?
    @State private var form: ActivityFormViewModel
    @State private var expanded = false
    @State private var discard = false
    @State private var saveError = false
    @State private var nextDose: NextDosePrompt?
    @State private var episodeOffer: Date?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoError: String?
    @ScaledMetric(relativeTo: .largeTitle) private var measurementSize: CGFloat = 48

    init(kind: ActivityKind, activity: CareActivity? = nil, completingReminderID: UUID? = nil, onSave: ((CareActivity) -> Void)? = nil) {
        self.kind = kind
        self.activity = activity
        self.completingReminderID = completingReminderID
        self.onSave = onSave
        _form = State(initialValue: ActivityFormViewModel(kind: kind, activity: activity))
    }

    private var isEditing: Bool { activity.map { existing in viewModel.activities.contains { $0.id == existing.id } } ?? false }
    private var value: String {
        get { form.state.value }
        nonmutating set { form.send(.value(newValue)) }
    }
    private var unit: String {
        get { form.state.unit }
        nonmutating set { form.send(.unit(newValue)) }
    }
    private var date: Date {
        get { form.state.date }
        nonmutating set { form.send(.date(newValue)) }
    }
    private var note: String {
        get { form.state.note }
        nonmutating set { form.send(.note(newValue)) }
    }
    private var detail: String {
        get { form.state.detail }
        nonmutating set { form.send(.detail(newValue)) }
    }
    private var symptoms: Set<String> {
        get { form.state.symptoms }
        nonmutating set { form.send(.symptoms(newValue)) }
    }
    private var attachments: [Data] {
        get { form.state.attachments }
        nonmutating set { form.send(.attachments(newValue)) }
    }
    private var loadingPhotos: Bool {
        get { form.state.loadingPhotos }
        nonmutating set { form.send(.loadingPhotos(newValue)) }
    }
    private var dirty: Bool { form.state.dirty }
    private var numeric: Bool { form.numeric }
    private var number: Double? { form.number }
    private var valid: Bool { form.valid && !viewModel.state.isSaving }
    private var validationMessage: String { form.validationMessage }

    @Environment(\.locale) private var appLocale
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var body: some View {
        let _ = appLocale
        ScrollView {
            VStack(spacing: 16) {
            // Compact height (folded iPhone Duo or any iPhone in landscape) keeps the input above the fold.
            if verticalSizeClass != .compact {
            CareFormCard {
                HStack(spacing: 12) {
                    CareIcon(name: kind.assetName, color: kind.group.color, size: 25)
                        .frame(width: 46, height: 46).background(kind.group.background, in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("Ghi cho {0}", "\(viewModel.baby.name)")).font(CareFont.headline)
                        Text(viewModel.baby.ageDescription).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }
                }
            }.listRowBackground(Color.clear)
            }

            if kind == .temperature { temperatureSection }
            else { fieldsSection }

            CareFormCard {
                if kind == .temperature {
                    Text(L10n.text("Vị trí đo")).font(CareFont.headline)
                    VStack {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 8) {
                            ForEach(["Chưa rõ", "Nách", "Tai", "Trán", "Khác"], id: \.self) { site in
                                Button { detail = site } label: {
                                    VStack(spacing: 6) {
                                        CareIcon(name: siteIcon(site), color: detail == site ? CareTheme.accent : CareTheme.secondary, size: 24)
                                        Text(L10n.text(site)).font(CareFont.footnote.weight(.semibold))
                                    }
                                        .padding(.horizontal, 16).frame(minHeight: 48)
                                        .foregroundStyle(detail == site ? CareTheme.accent : CareTheme.secondary)
                                        .background(detail == site ? CareTheme.accent.opacity(0.1) : CareTheme.background, in: .rect(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(detail == site ? CareTheme.accent : CareTheme.border))
                                }.buttonStyle(.plain).accessibilityAddTraits(detail == site ? .isSelected : [])
                            }
                        }
                    }
                }
                CareDateTimeField(title: kind == .sleep ? (detail == CareActivity.recordedSleepDetail ? L10n.text("Thời điểm ghi nhận") : L10n.text("Bắt đầu ngủ")) : kind == .temperature ? L10n.text("Thời điểm đo") : L10n.text("Thời điểm"), selection: Binding(get: { date }, set: { date = $0 }), earliest: viewModel.baby.birthDate)
            }

            CareFormCard {
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "Stitch_help_outline", color: CareTheme.accent, size: 20)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Kiểm tra trước khi lưu")).font(CareFont.subheadline.weight(.semibold))
                        Text(kind == .medicine ? L10n.text("Ghi đúng tên, đơn vị và lượng đã dùng theo hướng dẫn bạn đang có.") : kind == .temperature ? L10n.text("Nhập số đang hiển thị trên nhiệt kế và chọn đúng vị trí đo. Số đo trước chỉ dùng để tham khảo.") : L10n.text("Kiểm tra thời gian và nội dung đã nhập cho bé."))
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                }.padding(.vertical, 5)
            }.listRowBackground(CareTheme.accent.opacity(0.06))

            CareFormCard {
                DisclosureGroup(L10n.text("Thêm chi tiết (Ảnh & Ghi chú)"), isExpanded: $expanded) {
                    if ![.medicine, .temperature, .milk, .symptom].contains(kind) {
                        TextField(L10n.text("Thông tin thêm"), text: Binding(get: { detail }, set: { detail = $0 }), axis: .vertical)
                    }
                    TextField(L10n.text("Ghi chú"), text: Binding(get: { note }, set: { note = $0 }), axis: .vertical).lineLimit(3...6)
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(1, 3 - attachments.count), matching: .images) {
                        Label(L10n.text("Thêm ảnh ({0}/3)", "\(attachments.count)"), systemImage: "photo.badge.plus")
                    }.disabled(attachments.count >= 3 || loadingPhotos)
                    if loadingPhotos { ProgressView(L10n.text("Đang tải ảnh")) }
                    if let photoError {
                        Text(photoError).font(CareFont.footnote).foregroundStyle(CareTheme.medical)
                    }
                    if !attachments.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Array(attachments.enumerated()), id: \.offset) { index, data in
                                    VStack {
                                        #if canImport(UIKit)
                                        if let image = CareImageProcessor.thumbnail(data, maximumPixels: 240) {
                                            Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 80).clipped().clipShape(.rect(cornerRadius: 8))
                                        }
                                        #endif
                                        Button(L10n.text("Gỡ ảnh {0}", "\(index + 1)")) { if attachments.indices.contains(index), attachments[index] == data { attachments.remove(at: index) } }.font(CareFont.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if saveError { CareFormCard { Text(L10n.text("Chưa lưu được. Hãy thử lại.")).foregroundStyle(CareTheme.medical) } }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen()
        .scrollDismissesKeyboard(.interactively)
        .textFieldStyle(CareInputStyle())
        .navigationTitle("\(isEditing ? L10n.text("Sửa") : L10n.text("Ghi")) \(kind.title.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("Hủy")) { dirty ? (discard = true) : dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) { HStack { if viewModel.state.isSaving { ProgressView() }; Text(L10n.text("Lưu")) } }.disabled(!valid)
                    .accessibilityIdentifier(verticalSizeClass == .compact ? "saveActivityButton" : "saveActivityToolbarButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Compact height: the toolbar Save is enough, so only the validation hint stays at the bottom.
            if verticalSizeClass == .compact {
                if !valid {
                    Text(validationMessage).font(CareFont.caption).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
                        .padding(8).frame(maxWidth: .infinity).background(CareTheme.background)
                }
            } else {
                VStack(spacing: 6) {
                    CarePrimaryButton(title: isEditing ? L10n.text("Lưu thay đổi") : L10n.text("Lưu {0}", "\(kind.title.lowercased())"), icon: "Stitch_check_circle", isLoading: viewModel.state.isSaving, action: save)
                        .disabled(!valid).accessibilityIdentifier("saveActivityButton")
                    if !valid { Text(validationMessage).font(CareFont.caption).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center) }
                }.padding().background(CareTheme.background)
            }
        }
        .interactiveDismissDisabled(dirty || viewModel.state.isSaving)
        .navigationBarBackButtonHidden(dirty)
        .confirmationDialog(L10n.text("Bỏ nội dung chưa lưu?"), isPresented: $discard, titleVisibility: .visible) {
            Button(L10n.text("Bỏ nội dung"), role: .destructive) { dismiss() }
            Button(L10n.text("Tiếp tục nhập"), role: .cancel) { }
        }
        .sheet(item: $nextDose) { prompt in
            NextDoseView(prompt: prompt) { nextDose = nil; dismiss() }
        }
        .confirmationDialog(L10n.text("Bắt đầu theo dõi ốm?"), isPresented: Binding(get: { episodeOffer != nil }, set: { if !$0 { episodeOffer = nil; dismiss() } }), titleVisibility: .visible) {
            Button(L10n.text("Bắt đầu theo dõi")) {
                let start = Calendar.current.startOfDay(for: episodeOffer ?? Date())
                Task { _ = await viewModel.send(.commit(.startIllness(babyID: viewModel.baby.id, title: "", date: start), message: L10n.text("Đã bắt đầu theo dõi"))) }
            }
            Button(L10n.text("Không, chỉ ghi nhiệt độ"), role: .cancel) { }
        } message: { Text(L10n.text("Gom nhiệt độ, thuốc và triệu chứng vào một đợt để theo dõi diễn biến. Bạn có thể kết thúc bất cứ lúc nào.")) }
        .task(id: selectedPhotos) {
            let items = selectedPhotos
            guard !items.isEmpty else { return }
            loadingPhotos = true
            photoError = nil
            defer { loadingPhotos = false }
            for item in items.prefix(max(0, 3 - attachments.count)) {
                let data = try? await item.loadTransferable(type: Data.self)
                guard !Task.isCancelled else { return }
                if let data, let prepared = CareImageProcessor.jpeg(data) {
                    attachments.append(prepared)
                } else {
                    photoError = L10n.text("Không thể chuẩn hóa ảnh hoặc ảnh vượt quá 5 MB. Hãy chọn ảnh khác.")
                }
            }
            selectedPhotos = []
        }
    }

    private func siteIcon(_ site: String) -> String {
        switch site {
        case "Nách": "Stitch_accessibility_new"
        case "Tai": "Stitch_hearing"
        case "Trán": "Stitch_face"
        case "Khác": "Stitch_more_horiz"
        default: "Stitch_help_outline"
        }
    }

    private var temperatureSection: some View {
        CareFormCard {
            VStack(spacing: 18) {
                Text(L10n.text("NHIỆT ĐỘ CƠ THỂ")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                HStack(alignment: .center, spacing: 8) {
                    Button(L10n.text("Giảm 0,1 độ"), systemImage: "minus") { adjust(-0.1) }
                        .labelStyle(.iconOnly).buttonStyle(.bordered).buttonBorderShape(.circle).frame(width: 48, height: 48).disabled(number == nil)
                    TextField("—", text: Binding(get: { value }, set: { value = $0 })).keyboardType(.decimalPad).multilineTextAlignment(.center)
                        .font(.custom("BeVietnamPro-Bold", fixedSize: measurementSize)).minimumScaleFactor(0.6).textFieldStyle(.plain)
                        .accessibilityLabel(L10n.text("Nhiệt độ")).accessibilityIdentifier("temperatureField")
                    Text("°C").font(CareFont.title2.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                    Button(L10n.text("Tăng 0,1 độ"), systemImage: "plus") { adjust(0.1) }
                        .labelStyle(.iconOnly).buttonStyle(.bordered).buttonBorderShape(.circle).frame(width: 48, height: 48).disabled(number == nil)
                }
                Text(L10n.text("Chạm nút để tinh chỉnh ±0,1°C")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                if let previous = viewModel.activities.first(where: { $0.kind == .temperature }) {
                    Text(L10n.text("Lần đo trước: {0} · {1}", "\(previous.formattedValue)", "\(previous.date.careFormatted(date: .abbreviated, time: .shortened))"))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }.padding(.vertical, 16)
        }
    }

    @ViewBuilder private var fieldsSection: some View {
        CareFormCard(title: kind.title) {
            if kind == .medicine {
                TextField(L10n.text("Tên thuốc · Bắt buộc"), text: Binding(get: { detail }, set: { detail = $0 }))
                Text(L10n.text("Thêm nồng độ / hàm lượng nếu biết")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            if kind == .milk {
                Picker(L10n.text("Loại sữa"), selection: Binding(get: { detail }, set: { detail = $0 })) {
                    ForEach(["Sữa công thức", "Sữa mẹ vắt", "Bú mẹ"], id: \.self) { Text(L10n.text($0)).tag($0) }
                }
            }
            if kind == .symptom {
                ForEach(["Ho", "Sổ mũi", "Nôn", "Tiêu chảy", "Phát ban", "Mệt", "Khác"], id: \.self) { symptom in
                    Toggle(L10n.text(symptom), isOn: Binding(get: { symptoms.contains(symptom) }, set: { if $0 { symptoms.insert(symptom) } else { symptoms.remove(symptom) } }))
                }
                if symptoms.contains("Khác") { TextField(L10n.text("Mô tả triệu chứng khác · Bắt buộc"), text: Binding(get: { detail }, set: { detail = $0 }), axis: .vertical) }
            } else if numeric {
                HStack {
                    TextField(kind == .sleep ? L10n.text("Thời lượng") : L10n.text("Lượng thực tế"), text: Binding(get: { value }, set: { value = $0 })).keyboardType(.decimalPad)
                    if kind == .medicine {
                        Picker(L10n.text("Đơn vị"), selection: Binding(get: { unit }, set: { unit = $0 })) {
                            ForEach(["", "ml", "mg", "viên", "gói", "giọt", "lần xịt"], id: \.self) { Text($0.isEmpty ? L10n.text("Chọn đơn vị") : L10n.text($0)).tag($0) }
                        }.labelsHidden()
                    } else { Text(L10n.text(unit)).foregroundStyle(CareTheme.secondary) }
                }
            } else if kind == .diaper {
                Picker(L10n.text("Nội dung"), selection: Binding(get: { value }, set: { value = $0 })) {
                    ForEach(["", "Thay tã", "Đi tiểu", "Đi ngoài", "Cả hai"], id: \.self) { Text($0.isEmpty ? L10n.text("Chưa chọn") : L10n.text($0)).tag($0) }
                }
            } else {
                TextField(kind == .doctor ? L10n.text("Lý do khám · Bắt buộc") : kind == .bath ? L10n.text("Mô tả (tùy chọn)") : L10n.text("Nội dung · Bắt buộc"), text: Binding(get: { value }, set: { value = $0 }), axis: .vertical)
            }
        }
    }
    private func adjust(_ amount: Double) { form.send(.adjust(amount)) }
    private func save() {
        guard valid, let entry = form.makeEntry() else { return }
        if let onSave { onSave(entry); dismiss(); return }
        let finishingSleep = kind == .sleep && !isEditing && viewModel.sleepStartDate == activity?.date ? viewModel.sleepStartDate : nil
        // Offer an episode once per cluster of readings; the parent decides, nothing is diagnosed.
        let offerEpisode = kind == .temperature && !isEditing && !viewModel.isTrackingIllness
            && !viewModel.activities.contains { $0.kind == .temperature && $0.id != entry.id && abs($0.date.timeIntervalSince(entry.date)) < 86_400 }
        Task {
            guard await viewModel.send(.commit(.saveActivities(babyID: viewModel.baby.id, entries: [entry], finishingSleep: finishingSleep,
                completingReminderID: completingReminderID), message: isEditing ? L10n.text("Đã cập nhật") : L10n.text("Đã lưu {0}", "\(kind.title.lowercased())"))) else { saveError = true; return }
            if let completingReminderID, let reminder = viewModel.medicationReminders.first(where: { $0.id == completingReminderID }) {
                nextDose = NextDosePrompt(reminder: reminder, takenAt: entry.date)
            } else if offerEpisode {
                episodeOffer = entry.date
            } else {
                dismiss()
            }
        }
    }
}
#Preview { NavigationStack { ActivityFormView(kind: .temperature) }.environment(BabyCareViewModel.preview()) }
