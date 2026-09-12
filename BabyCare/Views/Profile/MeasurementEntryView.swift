import SwiftUI

/// Stitch G — native view backed by the existing data provider.
struct MeasurementEntryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var measurementID = UUID()
    @State private var weight = ""
    @State private var height = ""
    @State private var headCircumference = ""
    @State private var date = Date()
    @State private var method = "Chưa rõ"
    @State private var notes = ""
    @State private var showDetails = false
    @State private var confirmDiscard = false
    @State private var duplicateMessage: String?
    private let existingMeasurement: BodyMeasurement?

    init(measurement: BodyMeasurement? = nil) {
        existingMeasurement = measurement
        _weight = State(initialValue: measurement?.weight.map { String($0) } ?? "")
        _height = State(initialValue: measurement?.height.map { String($0) } ?? "")
        _headCircumference = State(initialValue: measurement?.headCircumference.map { String($0) } ?? "")
        _date = State(initialValue: measurement?.date ?? Date())
        _method = State(initialValue: measurement?.method.isEmpty == false ? measurement!.method : "Chưa rõ")
        _notes = State(initialValue: measurement?.notes ?? "")
    }

    private var weightValue: Double? { number(weight) }
    private var heightValue: Double? { number(height) }
    private var headValue: Double? { number(headCircumference) }
    private var hasChanges: Bool {
        weight != (existingMeasurement?.weight.map { String($0) } ?? "")
        || height != (existingMeasurement?.height.map { String($0) } ?? "")
        || headCircumference != (existingMeasurement?.headCircumference.map { String($0) } ?? "")
        || notes != (existingMeasurement?.notes ?? "")
    }
    private var isValid: Bool {
        (!weight.isEmpty || !height.isEmpty || !headCircumference.isEmpty)
        && [weight, height, headCircumference].allSatisfy { $0.isEmpty || (number($0) ?? 0) > 0 }
        && date >= viewModel.baby.birthDate && date <= Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
            CareFormCard {
                HStack(spacing: 12) {
                    CareIcon(name: "Stitch_query_stats", color: CareTheme.feeding, size: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("THEO DÕI TĂNG TRƯỞNG").font(CareFont.caption).bold().foregroundStyle(CareTheme.feeding)
                        Text("Số đo của bé được cập nhật vào hồ sơ và biểu đồ tăng trưởng.").font(CareFont.subheadline)
                    }
                }.padding(.vertical, 5)
            }.listRowBackground(CareTheme.feedingBackground)

            CareFormCard {
                measurementField("Cân nặng của bé", value: $weight, unit: "kg", icon: "Stitch_scale", step: 0.05)
                if let last = viewModel.measurements.filter({ $0.weight != nil }).max(by: { $0.date < $1.date }), let lastWeight = last.weight {
                    Text("Lần trước: \(lastWeight.formatted()) kg · \(last.date.careFormatted(date: .abbreviated, time: .omitted))")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }

            CareFormCard {
                measurementField("Chiều dài / chiều cao", value: $height, unit: "cm", icon: "Stitch_straighten", step: 0.5)
                Picker("Phương pháp đo", selection: $method) {
                    Text("Nằm đo").tag("Nằm đo")
                    Text("Đứng đo").tag("Đứng đo")
                    Text("Chưa rõ").tag("Chưa rõ")
                }
                .pickerStyle(.segmented)
            }

            CareFormCard {
                CareDateTimeField(title: "Thời điểm đo", selection: $date, earliest: viewModel.baby.birthDate)
                DisclosureGroup("Thêm chi tiết", isExpanded: $showDetails) {
                    TextField("Vòng đầu (cm) · Tùy chọn", text: $headCircumference)
                        .keyboardType(.decimalPad)
                    TextField("Ghi chú · Tùy chọn", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                Text("Nhập ít nhất một số đo dương.").font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
            }
            if let duplicateMessage {
                CareFormCard { Text(duplicateMessage).font(CareFont.footnote).foregroundStyle(CareTheme.medical) }
            }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(CareTheme.background)
        .foregroundStyle(CareTheme.text)
        .navigationTitle(existingMeasurement == nil ? "Nhập số đo cơ thể" : "Sửa số đo cơ thể")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationSubtitle("Ghi cho \(viewModel.baby.name)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Hủy") { if hasChanges { confirmDiscard = true } else { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Lưu", action: save).disabled(!isValid) }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                CarePrimaryButton(title: "Lưu số đo", icon: "Stitch_check_circle", action: save).disabled(!isValid)
                    .accessibilityIdentifier("saveMeasurementButton")
                if !isValid {
                    Text("Nhập ít nhất một số đo hợp lệ để lưu.")
                        .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                }
            }.padding().background(CareTheme.background)
        }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Bỏ nội dung chưa lưu?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Bỏ nội dung", role: .destructive) { dismiss() }
            Button("Tiếp tục nhập", role: .cancel) { }
        }
    }

    private func measurementField(_ title: String, value: Binding<String>, unit: String, icon: String, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                CareIcon(name: icon, color: CareTheme.accent, size: 22)
                Text(title).font(CareFont.headline)
            }
            HStack(spacing: 8) {
                Button { adjust(value, step: -step) } label: {
                    Image(systemName: "minus").frame(width: 48, height: 48)
                }.buttonStyle(.plain).background(CareTheme.background, in: .circle)
                    .accessibilityLabel("Giảm " + title.lowercased()).disabled(number(value.wrappedValue) == nil)
                TextField("—", text: value)
                    .keyboardType(.decimalPad)
                    .font(.custom("BeVietnamPro-Bold", size: 38, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center).minimumScaleFactor(0.65)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(unit == "kg" ? "weightField" : "heightField")
                Text(unit).font(CareFont.headline).foregroundStyle(CareTheme.secondary)
                Button { adjust(value, step: step) } label: {
                    Image(systemName: "plus").frame(width: 48, height: 48)
                }.buttonStyle(.plain).background(CareTheme.background, in: .circle)
                    .accessibilityLabel("Tăng " + title.lowercased()).disabled(number(value.wrappedValue) == nil)
            }
            Text("Bước tinh chỉnh \(step.formatted()) \(unit)")
                .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                .frame(maxWidth: .infinity)
        }.padding(.vertical, 8)
    }

    private func adjust(_ value: Binding<String>, step: Double) {
        guard let current = number(value.wrappedValue) else { return }
        let adjusted = current + step
        guard adjusted > 0 else { return }
        value.wrappedValue = String(format: "%.2f", adjusted)
    }

    private func number(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        return value
    }

    private func save() {
        guard isValid else { return }
        let duplicate = viewModel.measurements.contains { item in
            item.id != existingMeasurement?.id && item.date == date && (
                (weightValue != nil && item.weight != nil)
                || (heightValue != nil && item.height != nil)
                || (headValue != nil && item.headCircumference != nil)
            )
        }
        guard !duplicate else {
            duplicateMessage = "Đã có số đo này tại cùng thời điểm. Hãy đổi giờ hoặc sửa bản ghi trong Lịch sử tăng trưởng."
            return
        }
        duplicateMessage = nil
        let measurement = BodyMeasurement(id: existingMeasurement?.id ?? measurementID, date: date, weight: weightValue, height: heightValue, headCircumference: headValue, method: method, notes: notes)
        Task {
            guard await viewModel.send(.commit(.saveMeasurement(babyID: viewModel.baby.id, measurement: measurement),
                message: existingMeasurement == nil ? "Đã lưu số đo" : "Đã cập nhật số đo")) else { return }
            dismiss()
        }
    }
}

#Preview {
    NavigationStack { MeasurementEntryView().environment(BabyCareViewModel.preview()) }
}
