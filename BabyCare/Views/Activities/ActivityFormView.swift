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
    @State private var showingTemperatureInfo = false
    @State private var showingBreathingInfo = false
    @State private var showingCamera = false
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
    private var temperature: TemperatureDetail {
        get { TemperatureDetail(detail) }
        nonmutating set { detail = newValue.detail }
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
                if kind == .temperature { temperatureSiteFields }
                CareDateTimeField(title: kind == .sleep ? (detail == CareActivity.recordedSleepDetail ? L10n.text("Thời điểm ghi nhận") : L10n.text("Bắt đầu ngủ")) : kind == .temperature ? L10n.text("Thời điểm đo") : kind == .breathing ? L10n.text("Thời điểm đếm") : L10n.text("Thời điểm"), selection: Binding(get: { date }, set: { date = $0 }), earliest: viewModel.baby.birthDate)
                if form.tracksSleepEnd {
                    CareDateTimeField(title: L10n.text("Thức dậy"), selection: Binding(get: { form.sleepEnd ?? date }, set: { form.send(.sleepEnd($0)) }), earliest: date)
                }
            }

            CareFormCard {
                HStack(alignment: .top, spacing: 10) {
                    CareIcon(name: "Stitch_help_outline", color: CareTheme.accent, size: 20)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Kiểm tra trước khi lưu")).font(CareFont.subheadline.weight(.semibold))
                        Text(checkHint)
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                }.padding(.vertical, 5)
            }.listRowBackground(CareTheme.accent.opacity(0.06))

            CareFormCard {
                DisclosureGroup(L10n.text("Thêm chi tiết (Ảnh & Ghi chú)"), isExpanded: $expanded) {
                    if ![.medicine, .temperature, .milk, .symptom, .breathing, .doctor].contains(kind) {
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
        .sheet(isPresented: $showingTemperatureInfo) { TemperatureReferenceView(site: temperature.site) }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { image in
                // Same size and format checks as photos picked from the library.
                if attachments.count < 3, let data = image.jpegData(compressionQuality: 0.9), let prepared = CareImageProcessor.jpeg(data) {
                    attachments.append(prepared)
                    photoError = nil
                } else {
                    photoError = L10n.text("Không thể chuẩn hóa ảnh hoặc ảnh vượt quá 5 MB. Hãy chọn ảnh khác.")
                }
            }.ignoresSafeArea()
        }
        #endif
        .sheet(isPresented: $showingBreathingInfo) { BreathingReferenceView(current: breathingBand) }
        .onChange(of: attachments.count) { old, new in if kind == .medicine && new > old { expanded = true } }
        .sheet(item: $nextDose) { prompt in
            NextDoseView(prompt: prompt) { nextDose = nil; dismiss() }
        }
        .alert(L10n.text("Bắt đầu theo dõi ốm?"), isPresented: Binding(get: { episodeOffer != nil }, set: { if !$0 { episodeOffer = nil; dismiss() } })) {
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

    private var checkHint: String {
        switch kind {
        case .medicine: L10n.text("Ghi đúng tên, đơn vị và lượng đã dùng theo hướng dẫn bạn đang có.")
        case .temperature: L10n.text("Nhập số đang hiển thị trên nhiệt kế và chọn đúng vị trí đo. Số đo trước chỉ dùng để tham khảo.")
        case .breathing: L10n.text("Đếm đủ 1 phút khi bé ngủ hoặc nằm yên; mỗi lần ngực hoặc bụng nhô lên là 1 nhịp.")
        case .sleep: L10n.text("Có thể ghi sau khi bé đã ngủ dậy: chọn giờ bắt đầu và giờ thức dậy.")
        case .doctor: L10n.text("Ghi lại lời dặn và lịch hẹn để không quên tái khám.")
        default: L10n.text("Kiểm tra thời gian và nội dung đã nhập cho bé.")
        }
    }
    private var breathingBand: BreathingReference.Band? { BreathingReference.band(birthDate: viewModel.baby.birthDate, at: date) }

    @ViewBuilder private var temperatureSiteFields: some View {
        HStack {
            Text(L10n.text("Vị trí đo")).font(CareFont.headline)
            Spacer()
            Button { showingTemperatureInfo = true } label: { Image(systemName: "info.circle").font(.title3) }
                .frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("Nhiệt độ bình thường theo vị trí đo"))
                .accessibilityIdentifier("temperature.info")
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 8) {
            ForEach(TemperatureDetail.sites, id: \.self) { site in
                let selected = temperature.site == site
                Button { temperature = TemperatureDetail(site: site, thermometer: temperature.thermometer) } label: {
                    VStack(spacing: 6) {
                        CareIcon(name: siteIcon(site), color: selected ? CareTheme.accent : CareTheme.secondary, size: 24)
                        Text(L10n.text(site)).font(CareFont.footnote.weight(.semibold))
                    }
                        .padding(.horizontal, 16).frame(minHeight: 48)
                        .foregroundStyle(selected ? CareTheme.accent : CareTheme.secondary)
                        .background(selected ? CareTheme.accent.opacity(0.1) : CareTheme.background, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? CareTheme.accent : CareTheme.border))
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        if let row = TemperatureReference.row(for: temperature.site) {
            Text(L10n.text("Bình thường khi đo ở {0}: {1}", L10n.text(row.site).lowercased(), TemperatureReference.rangeText(row.range)))
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        }
        Text(L10n.text("Loại nhiệt kế")).font(CareFont.headline)
        CareChoiceChips(options: TemperatureDetail.thermometers,
            selection: Binding(get: { temperature.thermometer }, set: { temperature = TemperatureDetail(site: temperature.site, thermometer: $0) }))
    }

    private func siteIcon(_ site: String) -> String {
        switch site {
        case "Nách": "Stitch_accessibility_new"
        case "Hậu môn": "Stitch_child_care"
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
            if kind == .medicine { medicineFields }
            else if kind == .symptom { symptomFields }
            else if kind == .allergy {
                AllergyNoteFields(note: Binding(get: { form.state.allergy }, set: { form.send(.allergy($0)) }))
            } else if kind == .meal {
                TextField(L10n.text("Thực phẩm (tùy chọn)"), text: Binding(get: { value }, set: { value = $0 }), axis: .vertical)
                    .accessibilityIdentifier("meal.food")
                TextField(L10n.text("Số lượng (tùy chọn), vd. 1/2 bát"), text: Binding(get: { unit }, set: { unit = $0 }))
                    .accessibilityIdentifier("meal.amount")
            } else if kind == .breathing { breathingFields }
            else if kind == .doctor { doctorFields }
            else if form.tracksSleepEnd { sleepSummary }
            else if numeric {
                if kind == .milk {
                    Picker(L10n.text("Loại sữa"), selection: Binding(get: { detail }, set: { detail = $0 })) {
                        ForEach(["Sữa công thức", "Sữa mẹ vắt", "Bú mẹ"], id: \.self) { Text(L10n.text($0)).tag($0) }
                    }
                }
                amountRow
            } else if kind == .diaper {
                Picker(L10n.text("Nội dung"), selection: Binding(get: { value }, set: { value = $0 })) {
                    ForEach(["", "Thay tã", "Đi tiểu", "Đi ngoài", "Cả hai"], id: \.self) { Text($0.isEmpty ? L10n.text("Chưa chọn") : L10n.text($0)).tag($0) }
                }
            } else {
                TextField(kind == .doctor ? L10n.text("Lý do khám · Bắt buộc") : kind == .bath ? L10n.text("Mô tả (tùy chọn)") : L10n.text("Nội dung · Bắt buộc"), text: Binding(get: { value }, set: { value = $0 }), axis: .vertical)
            }
        }
    }

    private var amountRow: some View {
        HStack {
            TextField(kind == .sleep ? L10n.text("Thời lượng") : L10n.text("Lượng thực tế"), text: Binding(get: { value }, set: { value = $0 })).keyboardType(.decimalPad)
            if kind == .medicine {
                Picker(L10n.text("Đơn vị"), selection: Binding(get: { unit }, set: { unit = $0 })) {
                    ForEach(["", "ml", "mg", "viên", "gói", "giọt", "lần xịt"], id: \.self) { Text($0.isEmpty ? L10n.text("Chọn đơn vị") : L10n.text($0)).tag($0) }
                }.labelsHidden()
            } else { Text(L10n.text(unit)).foregroundStyle(CareTheme.secondary) }
        }
    }

    @ViewBuilder private var medicineFields: some View {
        TextField(L10n.text("Tên thuốc, hàm lượng nếu biết"), text: Binding(get: { detail }, set: { detail = $0 }))
            .accessibilityIdentifier("medicine.name")
        HStack(spacing: 10) {
            #if canImport(UIKit)
            if CameraCaptureView.isAvailable {
                Button { showingCamera = true } label: {
                    Label(L10n.text("Chụp ảnh"), systemImage: "camera").frame(maxWidth: .infinity, minHeight: 36)
                }.accessibilityIdentifier("medicine.camera")
            }
            #endif
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(1, 3 - attachments.count), matching: .images) {
                Label(L10n.text("Chọn từ album"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: 36)
            }.accessibilityIdentifier("medicine.album")
        }
        .buttonStyle(.bordered).tint(CareTheme.accent).font(CareFont.subheadline.weight(.semibold))
        .disabled(attachments.count >= 3 || loadingPhotos)
        Text(attachments.isEmpty ? L10n.text("Có ảnh hộp hoặc chai thuốc thì có thể bỏ trống tên.")
             : L10n.text("Đã thêm {0}/3 ảnh thuốc. Xem hoặc gỡ ở mục Thêm chi tiết bên dưới.", "\(attachments.count)"))
            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        Text(L10n.text("Lượng dùng")).font(CareFont.subheadline.weight(.semibold))
        amountRow
    }

    @ViewBuilder private var symptomFields: some View {
        ForEach(SymptomCatalog.names, id: \.self) { symptom in
            Toggle(L10n.text(symptom), isOn: Binding(get: { symptoms.contains(symptom) }, set: { if $0 { symptoms.insert(symptom) } else { symptoms.remove(symptom) } }))
                .accessibilityIdentifier("symptom.\(symptom)")
            let variants = SymptomCatalog.variants(for: symptom)
            if symptoms.contains(symptom) && !variants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SymptomCatalog.prompt(for: symptom)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    CareChoiceChips(options: variants, selection: Binding(get: { form.state.symptomVariants[symptom] ?? "" }, set: { form.send(.symptomVariant(symptom, $0)) }), color: CareTheme.medical,
                        title: { let text = L10n.text($0); return text.prefix(1).uppercased() + text.dropFirst() })
                }.padding(.leading, 12)
            }
        }
        if symptoms.contains("Khác") { TextField(L10n.text("Mô tả triệu chứng khác · Bắt buộc"), text: Binding(get: { detail }, set: { detail = $0 }), axis: .vertical) }
    }

    @ViewBuilder private var breathingFields: some View {
        HStack {
            TextField(L10n.text("Số nhịp trong 1 phút"), text: Binding(get: { value }, set: { value = $0 })).keyboardType(.numberPad)
                .accessibilityIdentifier("breathing.value")
            Text(L10n.text("lần/phút")).foregroundStyle(CareTheme.secondary)
        }
        BreathingCounter { value = String($0) }
        Text(L10n.text("Lúc đếm")).font(CareFont.subheadline.weight(.semibold))
        CareChoiceChips(options: BreathingReference.states, selection: Binding(get: { detail }, set: { detail = $0 }), clearable: false, color: CareTheme.medical)
        HStack(alignment: .top, spacing: 8) {
            Text(breathingBand.map { L10n.text("Mốc cho bé {0}: bình thường dưới {1} lần/phút (WHO).", L10n.text($0.title).lowercased(), "\($0.fastFrom)") }
                ?? L10n.text("Mốc nhịp thở của WHO dành cho trẻ dưới 5 tuổi."))
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            Spacer(minLength: 0)
            Button { showingBreathingInfo = true } label: { Image(systemName: "info.circle").font(.title3) }
                .frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("Nhịp thở bình thường theo tuổi"))
                .accessibilityIdentifier("breathing.info")
        }
    }

    @ViewBuilder private var doctorFields: some View {
        fieldLabel(L10n.text("Lý do khám"))
        TextField(L10n.text("Lý do khám · Bắt buộc"), text: Binding(get: { value }, set: { value = $0 }), axis: .vertical)
            .accessibilityIdentifier("doctor.reason")
        fieldLabel(L10n.text("Chẩn đoán của bác sĩ"))
        TextField(L10n.text("Chẩn đoán (nếu có), vd. viêm họng cấp"), text: Binding(get: { unit }, set: { unit = $0 }), axis: .vertical)
            .accessibilityIdentifier("doctor.diagnosis")
        fieldLabel(L10n.text("Lời dặn của bác sĩ"))
        TextField(L10n.text("Lời dặn của bác sĩ (nếu có)"), text: Binding(get: { detail }, set: { detail = $0 }), axis: .vertical)
            .lineLimit(2...6).accessibilityIdentifier("doctor.advice")
        Toggle(L10n.text("Hẹn khám lại"), isOn: Binding(get: { form.state.followUpDate != nil },
            set: { form.send(.followUp($0 ? DoctorFollowUp.suggestedDate(after: date) : nil)) }))
            .font(CareFont.subheadline.weight(.semibold)).accessibilityIdentifier("doctor.followUp")
        if let followUp = form.state.followUpDate {
            fieldLabel(L10n.text("Ngày giờ khám lại"))
            DatePicker(L10n.text("Ngày giờ khám lại"), selection: Binding(get: { followUp }, set: { form.send(.followUp($0)) }),
                       in: date.addingTimeInterval(60)..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden().font(CareFont.subheadline)
            let reminder = DoctorFollowUp.reminderDate(for: followUp)
            Label(reminder > .now ? L10n.text("Bé Khỏe sẽ nhắc lúc {0}, trước 2 ngày.", reminder.careFormatted(date: .abbreviated, time: .shortened))
                  : L10n.text("Lịch hẹn còn chưa tới 2 ngày nên không có nhắc trước."), systemImage: "bell")
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary).padding(.bottom, -8)
    }

    @ViewBuilder private var sleepSummary: some View {
        let minutes = Int(number ?? 0)
        let hours = L10n.count(minutes / 60, one: "1 giờ", many: "{0} giờ")
        Text(minutes <= 0 ? "—" : minutes < 60 ? L10n.text("{0} phút", "\(minutes)")
            : minutes % 60 == 0 ? hours : L10n.text("{0} giờ {1} phút", "\(minutes / 60)", "\(minutes % 60)"))
            .font(CareFont.title2.bold()).monospacedDigit().accessibilityIdentifier("sleep.duration")
        Text(L10n.text("Thời lượng tính từ giờ bắt đầu ngủ đến giờ thức dậy bên dưới."))
            .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        if let band = SleepRecommendation.band(birthDate: viewModel.baby.birthDate, at: date) {
            Label(L10n.text("Khuyến cáo cho bé {0}: {1}, gồm cả ngủ ngày (WHO).", L10n.text(band.title), SleepRecommendation.text(band)), systemImage: "moon.zzz")
                .font(CareFont.caption).foregroundStyle(CareTheme.routine)
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
