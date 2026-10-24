import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ReportSection: String, CaseIterable, Identifiable {
    case medical = "Y tế & Diễn tiến", feeding = "Lượng sữa & Ăn uống", routine = "Giấc ngủ & Sinh hoạt", growth = "Tăng trưởng"
    var id: Self { self }
    var icon: String { switch self { case .medical: "Stitch_stethoscope"; case .feeding: "Stitch_water_bottle"; case .routine: "Stitch_bedtime"; case .growth: "Stitch_trending_up" } }
    var color: Color { switch self { case .medical: CareTheme.medical; case .feeding: CareTheme.feeding; case .routine: CareTheme.routine; case .growth: CareTheme.accent } }
    var group: ActivityGroup? { switch self { case .medical: .medical; case .feeding: .feeding; case .routine: .routine; case .growth: nil } }
}

struct CareReportSnapshot: Identifiable {
    let id = UUID()
    let baby: BabyProfile
    let interval: DateInterval
    let createdAt = Date()
    let sections: Set<ReportSection>
    let activities: [CareActivity]
    let measurements: [BodyMeasurement]
    let includeProfile: Bool
    let includeBirthDate: Bool
    let includeHealthNotes: Bool
    let illnessTitle: String

    @MainActor init(viewModel: BabyCareViewModel, interval: DateInterval, sections: Set<ReportSection>, includeProfile: Bool = true, includeBirthDate: Bool = false, includeHealthNotes: Bool = true) {
        baby = viewModel.baby
        self.interval = interval
        self.sections = sections
        self.includeProfile = includeProfile
        self.includeBirthDate = includeBirthDate
        self.includeHealthNotes = includeHealthNotes
        illnessTitle = sections.contains(.medical) && viewModel.isTrackingIllness ? viewModel.illnessTitle : ""
        activities = viewModel.activities.filter { activity in
            let groupIncluded = sections.contains { $0.group == activity.kind.group }
            if activity.kind == .sleep, groupIncluded {
                return InsightData.sleepHours([activity], in: interval) != nil
            }
            return groupIncluded && interval.contains(activity.date)
        }.sorted { $0.date > $1.date }
        measurements = sections.contains(.growth) ? viewModel.measurements.filter { interval.contains($0.date) }.sorted { $0.date > $1.date } : []
    }

    var temperatureActivities: [CareActivity] { activities.filter { $0.kind == .temperature } }
    var medicineActivities: [CareActivity] { activities.filter { $0.kind == .medicine } }
    var newestTemperature: String { temperatureActivities.first.map { "\($0.value) °C" } ?? L10n.text("Chưa ghi nhận") }
    var highestTemperature: String { temperatureActivities.compactMap { InsightData.number($0.value) }.max().map { "\(InsightData.format($0)) °C" } ?? L10n.text("Chưa ghi nhận") }

    var documentLines: [String] {
        var lines = [L10n.text("BÉ KHỎE — BÁO CÁO CHĂM SÓC"), L10n.text("Khoảng dữ liệu: {0}", "\(InsightData.intervalLabel(interval))"), L10n.text("Tạo lúc: {0}", "\(createdAt.careFormatted(date: .abbreviated, time: .shortened))"), ""]
        if includeProfile {
            lines += ["\(baby.name) · \(baby.ageDescription)"]
            if includeBirthDate { lines += [L10n.text("Ngày sinh: {0} · {1}", "\(baby.birthDate.careFormatted(date: .abbreviated, time: .omitted))", "\(baby.gender.title)")] }
        }
        if includeHealthNotes {
            lines += [L10n.text("Tiền sử bệnh: {0}", "\(baby.medicalHistory.isEmpty ? L10n.text("Chưa cung cấp") : baby.medicalHistory)"),
                      L10n.text("Lưu ý sức khỏe: {0}", "\(baby.healthNotes.isEmpty ? L10n.text("Chưa cung cấp") : baby.healthNotes)"), L10n.text("Thông tin dị ứng: {0}", "\(baby.allergies.isEmpty ? L10n.text("Chưa cung cấp") : AllergyNote.display(baby.allergies, separator: "; "))")]
        }
        if !illnessTitle.isEmpty { lines += [L10n.text("Đợt theo dõi: {0}", "\(illnessTitle)")] }
        for section in ReportSection.allCases where sections.contains(section) {
            lines += ["", L10n.text(section.rawValue).uppercased()]
            if section == .growth {
                if measurements.isEmpty { lines += [L10n.text("Chưa có số đo trong khoảng này")] }
                for item in measurements {
                    let values = [item.weight.map { "\(InsightData.format($0)) kg" }, item.height.map { "\(InsightData.format($0)) cm" }, item.headCircumference.map { L10n.text("Vòng đầu {0} cm", "\(InsightData.format($0))") }].compactMap { $0 }.joined(separator: " · ")
                    lines += ["\(item.date.careFormatted(date: .abbreviated, time: .shortened)): \(values)"]
                }
            } else {
                let items = activities.filter { $0.kind.group == section.group }
                if items.isEmpty { lines += [L10n.text("Chưa có ghi nhận trong khoảng này")] }
                for item in items {
                    lines += ["\(item.date.careFormatted(date: .abbreviated, time: .shortened)) · \(item.kind.title)", [item.displayDetail, item.formattedValue, item.note,
                        item.followUpDate.map { L10n.text("Khám lại {0}", $0.careFormatted(date: .abbreviated, time: .shortened)) } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")]
                }
            }
        }
        lines += ["", L10n.text("Báo cáo do phụ huynh ghi nhận, phục vụ trao đổi với người chăm sóc hoặc bác sĩ. Không thay thế chẩn đoán của nhân viên y tế.")]
        return lines
    }
}

/// Stitch R — native view backed by the existing data provider.
struct ShareReportView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var interval: DateInterval
    @State private var sections = Set(ReportSection.allCases)
    @State private var includeProfile = true
    @State private var includeBirthDate = false
    @State private var includeHealthNotes = true
    @State private var showRange = false
    @State private var snapshot: CareReportSnapshot?
    @State private var exportURL: URL?
    @State private var error: String?
    @State private var didInitialize = false
    @State private var isGenerating = false
    init(interval: DateInterval? = nil) { _interval = State(initialValue: interval ?? InsightRange.hours48.interval()) }
    private var canPreview: Bool { includeProfile || includeHealthNotes || !sections.isEmpty }

    @Environment(\.locale) private var appLocale
    @Environment(\.careWindow) private var window
    @Environment(\.dynamicTypeSize) private var typeSize
    private var columns: Bool { window.allowsColumns(typeSize: typeSize) }

    private var exportControl: some View {
        VStack(spacing: 8) {
            if let exportURL {
                ShareLink(item: exportURL) {
                    HStack(spacing: 8) { CareIcon(name: "Stitch_ios_share", color: .white, size: 20); Text(L10n.text("Chia sẻ file PDF")).font(CareFont.headline) }
                        .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56).background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                CarePrimaryButton(title: isGenerating ? L10n.text("Đang tạo PDF…") : L10n.text("Xuất file PDF & Chia sẻ")) { export() }.disabled(!canPreview || isGenerating)
            }
        }
    }

    var body: some View {
        let _ = appLocale
        ScrollView {
            // Open iPhone Duo / iPad: choose the content on one side, check the preview on the other.
            CareColumns(spacing: 16) {
                CareCard {
                    HStack(alignment: .top, spacing: 12) {
                        CareIcon(name: "Stitch_health_and_safety", color: CareTheme.accent, size: 25)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.text("Bạn chọn nội dung chia sẻ")).font(CareFont.headline)
                            Text(L10n.text("PDF được tạo từ dữ liệu đã lưu trên thiết bị. Kiểm tra bản xem trước trước khi gửi.")).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                        }
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: 14) {
                        stepTitle(1, L10n.text("Chọn nội dung chia sẻ"), badge: L10n.text("{0}/4 mục", "\(sections.count)"))
                        Button { showRange = true } label: {
                            HStack(spacing: 12) {
                                CareIcon(name: "Stitch_calendar_today", color: CareTheme.accent, size: 20)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.text("Khoảng thời gian tổng hợp")).font(CareFont.subheadline.weight(.semibold)).foregroundStyle(CareTheme.text)
                                    Text(InsightData.intervalLabel(interval)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                }
                                Spacer()
                                Text(L10n.text("Sửa")).font(CareFont.subheadline)
                            }.padding(12).background(CareTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                        ForEach(ReportSection.allCases) { section in
                            Button {
                                if sections.contains(section) { sections.remove(section) } else { sections.insert(section) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    CareIcon(name: "Stitch_check_circle", color: sections.contains(section) ? section.color : CareTheme.border, size: 18)
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack(spacing: 6) {
                                            CareIcon(name: section.icon, color: section.color, size: 16)
                                            Text(L10n.text(section.rawValue)).font(CareFont.subheadline.weight(.semibold))
                                        }
                                        Text(summary(for: section)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }.foregroundStyle(section.color).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .background(section.color.opacity(sections.contains(section) ? 0.075 : 0.025), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(section.color.opacity(sections.contains(section) ? 0.25 : 0.08)))
                            }.buttonStyle(.plain).accessibilityLabel(L10n.text(section.rawValue)).accessibilityValue(sections.contains(section) ? L10n.text("Đã chọn") : L10n.text("Chưa chọn"))
                        }
                        DisclosureGroup(L10n.text("Thông tin hồ sơ")) {
                            VStack(spacing: 14) {
                                Toggle(L10n.text("Tên gọi và tuổi"), isOn: $includeProfile)
                                Toggle(L10n.text("Ngày sinh và giới tính"), isOn: $includeBirthDate).disabled(!includeProfile)
                                Toggle(L10n.text("Lưu ý sức khỏe và dị ứng"), isOn: $includeHealthNotes)
                            }.font(CareFont.subheadline).padding(.top, 12)
                        }.font(CareFont.subheadline.weight(.semibold))
                    }
                }
            } trailing: {
                CareCard {
                    VStack(alignment: .leading, spacing: 16) {
                        stepTitle(2, L10n.text("Xem trước phiếu tóm tắt"), badge: "PDF")
                        if let snapshot {
                            HStack(alignment: .top, spacing: 10) {
                                miniMetric(L10n.text("Thân nhiệt cao nhất"), value: snapshot.highestTemperature, color: CareTheme.medical)
                                miniMetric(L10n.text("Nhiệt độ gần nhất"), value: snapshot.newestTemperature, color: CareTheme.accent)
                            }
                            Text([L10n.count(snapshot.activities.count, one: "1 hoạt động", many: "{0} hoạt động"), L10n.count(snapshot.measurements.count, one: "1 số đo", many: "{0} số đo")].joined(separator: " · ")).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            NavigationLink { ReportPreviewView(snapshot: snapshot) } label: {
                                Text(L10n.text("Mở bản xem trước")).font(CareFont.headline).frame(maxWidth: .infinity, minHeight: 48)
                            }
                            Button(L10n.text("Cập nhật bản xem trước")) { makePreview() }.font(CareFont.subheadline).disabled(!canPreview)
                        } else {
                            Text(L10n.text("Bản xem trước chỉ chứa những mục bạn đã chọn.")).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            Button(L10n.text("Xem trước báo cáo")) { makePreview() }.font(CareFont.headline).frame(maxWidth: .infinity, minHeight: 48).disabled(!canPreview)
                        }
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        stepTitle(3, L10n.text("Mã QR & Liên kết"), badge: L10n.text("Chưa khả dụng"))
                        Text(L10n.text("Chia sẻ qua QR cần dịch vụ liên kết bảo mật. Bạn có thể xuất PDF và gửi bằng ứng dụng trên thiết bị.")).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                    }
                }
                if let error { Text(error).font(CareFont.subheadline).foregroundStyle(CareTheme.medical) }
                // Two columns: export follows the preview instead of a bar that would cross the iPhone Duo hinge.
                if columns { exportControl }
            }
        }
        .background(CareTheme.background).foregroundStyle(CareTheme.text)
        .navigationTitle(L10n.text("Chia sẻ báo cáo")).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if !columns { exportControl.padding(.horizontal, 20).padding(.vertical, 12).background(CareTheme.surface) }
        }
        .sheet(isPresented: $showRange) { InsightDateRangeView(start: interval.start, end: interval.end) { interval = $0 } }
        .onChange(of: sections) { _, _ in invalidatePreview() }
        .onChange(of: interval) { _, _ in invalidatePreview() }
        .onChange(of: includeProfile) { _, _ in invalidatePreview() }
        .onChange(of: includeBirthDate) { _, _ in invalidatePreview() }
        .onChange(of: includeHealthNotes) { _, _ in invalidatePreview() }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true
            sections = Set(ReportSection.allCases.filter { section in
                section == .growth ? viewModel.measurements.contains { interval.contains($0.date) } : viewModel.activities.contains { $0.kind.group == section.group && interval.contains($0.date) }
            })
        }
    }

    private func stepTitle(_ number: Int, _ title: String, badge: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").font(CareFont.caption.bold()).foregroundStyle(.white).frame(width: 22, height: 22).background(CareTheme.accent, in: Circle())
            Text(title).font(CareFont.headline)
            Spacer(minLength: 0)
            InsightBadge(title: badge)
        }
    }
    private func miniMetric(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(CareFont.caption).foregroundStyle(CareTheme.secondary); Text(value).font(CareFont.headline).foregroundStyle(color) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
    private func summary(for section: ReportSection) -> String {
        if section == .growth { return L10n.count(viewModel.measurements.filter { interval.contains($0.date) }.count, one: "1 số đo trong khoảng", many: "{0} số đo trong khoảng") }
        let count = viewModel.activities.filter { $0.kind.group == section.group && interval.contains($0.date) }.count
        return count > 0 ? L10n.count(count, one: "1 hoạt động đã ghi trong khoảng", many: "{0} hoạt động đã ghi trong khoảng") : L10n.text("Chưa có ghi nhận trong khoảng này")
    }
    private func invalidatePreview() { snapshot = nil; exportURL = nil; error = nil }
    private func makePreview() {
        snapshot = CareReportSnapshot(viewModel: viewModel, interval: interval, sections: sections, includeProfile: includeProfile, includeBirthDate: includeBirthDate, includeHealthNotes: includeHealthNotes)
    }
    private func export() {
        if snapshot == nil { makePreview() }
        guard let snapshot else { return }
        isGenerating = true
        defer { isGenerating = false }
        do { exportURL = try CareReportPDF.create(snapshot); error = nil }
        catch { self.error = L10n.text("Chưa tạo được PDF. Hãy thử lại.") }
    }
}

enum CareReportPDF {
    @MainActor static func create(_ snapshot: CareReportSnapshot) throws -> URL {
        #if canImport(UIKit)
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            var y: CGFloat = 48
            var page = 1
            let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.label]
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: UIColor(red: 0.08, green: 0.42, blue: 0.38, alpha: 1)]
            func beginPage() {
                context.beginPage()
                y = 48
                (L10n.text("Bé Khỏe · {0}", "\(page)") as NSString).draw(at: CGPoint(x: 48, y: 800), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray])
                page += 1
            }
            beginPage()
            for (index, line) in snapshot.documentLines.enumerated() {
                let attributes = index == 0 ? title : body
                // Break long freeform notes across pages instead of shrinking or clipping.
                let chunks = line.split(separator: "\n", omittingEmptySubsequences: false)
                for chunk in chunks {
                    let words = chunk.split(separator: " ", omittingEmptySubsequences: false)
                    var current = ""
                    var wrapped: [String] = []
                    for word in words {
                        let proposed = current.isEmpty ? String(word) : current + " " + word
                        if (proposed as NSString).size(withAttributes: attributes).width > 499 && !current.isEmpty { wrapped.append(current); current = String(word) }
                        else { current = proposed }
                    }
                    wrapped.append(current)
                    for text in wrapped {
                        if y + 22 > 770 { beginPage() }
                        (text as NSString).draw(in: CGRect(x: 48, y: y, width: 499, height: 30), withAttributes: attributes)
                        y += index == 0 ? 27 : 19
                    }
                }
                y += 5
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Be-Khoe-\(snapshot.id.uuidString).pdf")
        try data.write(to: url, options: .atomic)
        return url
        #else
        throw CocoaError(.featureUnsupported)
        #endif
    }
}

#Preview { NavigationStack { ShareReportView() }.environment(BabyCareViewModel.preview()) }
