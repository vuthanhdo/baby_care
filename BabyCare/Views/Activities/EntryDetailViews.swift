import SwiftUI

/// Name, severity and certainty of one allergy; shared by the allergy entry and the profile's allergy list.
struct AllergyNoteFields: View {
    @Binding var note: AllergyNote
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        VStack(alignment: .leading, spacing: 12) {
            TextField(L10n.text("Tên chất / tác nhân dị ứng · Bắt buộc"), text: $note.name)
                .accessibilityIdentifier("allergy.name")
            Text(L10n.text("Mức độ")).font(CareFont.subheadline.weight(.semibold))
            CareChoiceChips(options: AllergyNote.severities, selection: $note.severity, color: CareTheme.medical)
            Text(L10n.text("Độ chắc chắn")).font(CareFont.subheadline.weight(.semibold))
            CareChoiceChips(options: AllergyNote.certainties, selection: $note.certainty, color: CareTheme.medical)
            Text(L10n.text("Bỏ trống mức độ hoặc độ chắc chắn nếu chưa rõ."))
                .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
        }
    }
}

/// Counts breaths for one minute: the parent taps once per breath and the total fills the entry.
struct BreathingCounter: View {
    var onFinish: (Int) -> Void
    @State private var startedAt: Date?
    @State private var count = 0
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        if let startedAt {
            VStack(spacing: 10) {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let left = max(0, 60 - Int(context.date.timeIntervalSince(startedAt)))
                    Text(L10n.text("Còn {0} giây", "\(left)")).font(CareFont.subheadline.monospacedDigit())
                        .foregroundStyle(CareTheme.secondary)
                }
                Button { count += 1 } label: {
                    VStack(spacing: 4) {
                        Text("\(count)").font(CareFont.largeTitle.bold()).monospacedDigit()
                        Text(L10n.text("Chạm mỗi lần ngực bé nhô lên")).font(CareFont.caption)
                    }.foregroundStyle(CareTheme.medical).frame(maxWidth: .infinity, minHeight: 120)
                        .background(CareTheme.medicalBackground, in: .rect(cornerRadius: 16))
                }.buttonStyle(.plain).sensoryFeedback(.selection, trigger: count)
                    .accessibilityIdentifier("breathing.tap")
                Button(L10n.text("Dừng đếm")) { self.startedAt = nil }.font(CareFont.subheadline)
            }
            .task(id: startedAt) {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, self.startedAt == startedAt else { return }
                self.startedAt = nil
                if count > 0 { onFinish(count) }
            }
        } else {
            Button { count = 0; startedAt = .now } label: {
                Label(L10n.text("Đếm trong 60 giây"), systemImage: "timer").font(CareFont.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.bordered).tint(CareTheme.medical).accessibilityIdentifier("breathing.count")
        }
    }
}

extension TemperatureReference {
    static func rangeText(_ range: ClosedRange<Double>) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)).locale(AppLanguage.current.locale)
        return "\(range.lowerBound.formatted(style)) – \(range.upperBound.formatted(style)) °C"
    }
}

/// Usual temperature for each measuring site; opened from the info button beside the site picker.
struct TemperatureReferenceView: View {
    var site: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            List {
                Section {
                    ForEach(TemperatureReference.rows, id: \.site) { row in
                        LabeledContent(L10n.text(row.site), value: TemperatureReference.rangeText(row.range))
                            .fontWeight(row.site == site ? .semibold : .regular)
                    }
                    LabeledContent(L10n.text("Trán"), value: L10n.text("Theo hướng dẫn của nhiệt kế"))
                        .fontWeight(site == "Trán" ? .semibold : .regular)
                } header: {
                    Text(L10n.text("Nhiệt độ bình thường theo vị trí đo"))
                } footer: {
                    Text(L10n.text("Cùng một lúc, nhiệt độ hậu môn cao nhất, rồi đến tai và miệng; nách thấp nhất. Hãy so số đo với đúng vị trí đã đo."))
                }
                Section(L10n.text("Lưu ý")) {
                    Text(L10n.text("Nhiệt kế tai cho kết quả đáng tin hơn khi bé trên 6 tháng."))
                    Text(L10n.text("Không dùng nhiệt kế thủy ngân để đo hậu môn hoặc miệng cho bé vì dễ vỡ."))
                }
                Section {
                    Text(L10n.text("Khoảng tham khảo thường được các bệnh viện (như Vinmec) sử dụng. Thông tin không thay cho lời khuyên của bác sĩ."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }
            .font(CareFont.subheadline)
            .navigationTitle(L10n.text("Nhiệt độ bình thường")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Xong")) { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

/// WHO fast-breathing cut-offs by age and how to count; opened from the breathing entry.
struct BreathingReferenceView: View {
    var current: BreathingReference.Band?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        NavigationStack {
            List {
                Section {
                    ForEach(BreathingReference.bands, id: \.title) { band in
                        LabeledContent(L10n.text(band.title), value: L10n.text("dưới {0} lần/phút", "\(band.fastFrom)"))
                            .fontWeight(band == current ? .semibold : .regular)
                    }
                } header: {
                    Text(L10n.text("Nhịp thở bình thường theo tuổi"))
                } footer: {
                    Text(L10n.text("WHO coi nhịp thở từ mốc này trở lên là thở nhanh. Nếu bé thở nhanh, thở rít hoặc rút lõm lồng ngực, hãy hỏi bác sĩ."))
                }
                Section(L10n.text("Cách đếm")) {
                    Text(L10n.text("Đếm khi bé ngủ hoặc nằm yên, không khóc."))
                    Text(L10n.text("Mỗi lần ngực hoặc bụng nhô lên rồi hạ xuống là 1 nhịp."))
                    Text(L10n.text("Đếm đủ 60 giây."))
                }
                Section {
                    Text(L10n.text("Nguồn: hướng dẫn IMCI của WHO. Thông tin không thay cho lời khuyên của bác sĩ."))
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }
            .font(CareFont.subheadline)
            .navigationTitle(L10n.text("Nhịp thở của trẻ")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Xong")) { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

/// After a first fever reading: offers to follow the illness as an episode. A sheet rather than an alert, so the
/// choice reads as one main action and one way out, in the app's own buttons.
struct IllnessOfferSheet: View {
    let reading: CareActivity
    /// Starts the episode; returns why it failed, or nil once started.
    var start: () async -> String?
    var skip: () -> Void
    @State private var starting = false
    @State private var failure: String?
    @Environment(\.locale) private var appLocale

    var body: some View {
        let _ = appLocale
        VStack(spacing: 18) {
            CareIcon(name: "Stitch_thermostat", color: CareTheme.medical, size: 30)
                .frame(width: 64, height: 64).background(CareTheme.medicalBackground, in: .circle)
            VStack(spacing: 8) {
                Text(L10n.text("Bắt đầu theo dõi ốm?")).font(CareFont.title3.bold()).multilineTextAlignment(.center)
                Text(L10n.text("Gom nhiệt độ, thuốc và triệu chứng vào một đợt để theo dõi diễn biến. Bạn có thể kết thúc bất cứ lúc nào."))
                    .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.text("Vừa ghi: {0} lúc {1}", reading.formattedValue, reading.date.careFormatted(date: .omitted, time: .shortened)))
                .font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.medical)
                .padding(.horizontal, 14).padding(.vertical, 8).background(CareTheme.medicalBackground, in: .capsule)
            if let failure {
                Text(failure).font(CareFont.footnote).foregroundStyle(CareTheme.medical).multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                Button {
                    Task {
                        starting = true
                        failure = await start()
                        starting = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if starting { ProgressView().tint(.white) } else { CareIcon(name: "Stitch_clinical_notes", color: .white, size: 20) }
                        Text(L10n.text("Bắt đầu theo dõi"))
                    }
                }
                .buttonStyle(CareActionStyle(color: CareTheme.medical))
                .accessibilityIdentifier("illnessOffer.start")
                Button(L10n.text("Không, chỉ ghi nhiệt độ"), action: skip)
                    .buttonStyle(CareActionStyle(color: CareTheme.secondary, outlined: true))
                    .accessibilityIdentifier("illnessOffer.skip")
            }
            .disabled(starting)
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 16)
        .frame(maxWidth: 520)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Opaque: through the default glass the form's green save button glowed under the buttons.
        .presentationBackground(CareTheme.background)
        .interactiveDismissDisabled(starting)
    }
}

#if canImport(UIKit)
/// Takes one photo with the camera; PhotosPicker only reads the library.
struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
#endif
