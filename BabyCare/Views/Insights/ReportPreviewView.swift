import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

/// Stitch W — native view backed by the existing data provider.
/// A remote QR recipient page requires a backend; this screen is the local preview.
struct ReportPreviewView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var snapshot: CareReportSnapshot?
    @State private var exportURL: URL?
    @State private var error: String?
    @State private var chartList = false
    @State private var selectedDate: Date?
    init(snapshot: CareReportSnapshot? = nil) { _snapshot = State(initialValue: snapshot) }

    var body: some View {
        ScrollView {
            if let snapshot {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        CareBrandView(size: 44)
                        Text("Bé Khỏe").font(CareFont.headline)
                        Spacer()
                        InsightBadge(title: "BẢN XEM TRƯỚC")
                    }
                    summaryCard(snapshot)
                    if snapshot.sections.contains(.medical) { medicalCard(snapshot) }
                    if snapshot.sections.contains(.feeding) || snapshot.sections.contains(.routine) { nutritionCard(snapshot) }
                    if snapshot.sections.contains(.growth) { growthCard(snapshot) }
                    if snapshot.includeHealthNotes {
                        CareCard {
                            VStack(alignment: .leading, spacing: 10) {
                                CareSectionTitle(title: "Lưu ý sức khỏe")
                                Text(snapshot.baby.healthNotes.isEmpty ? "Chưa cung cấp lưu ý sức khỏe" : snapshot.baby.healthNotes).font(CareFont.subheadline)
                                Text("Dị ứng: \(snapshot.baby.allergies.isEmpty ? "Chưa cung cấp" : snapshot.baby.allergies)").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            }
                        }
                    }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            HStack(spacing: 8) {
                                CareIcon(name: "Stitch_picture_as_pdf", color: .white, size: 21)
                                Text("Lưu / chia sẻ PDF").font(CareFont.headline)
                            }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56).background(CareTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        CarePrimaryButton(title: "Tạo bản PDF") { createPDF(snapshot) }
                    }
                    #if canImport(UIKit)
                    Button { printReport(snapshot) } label: {
                        HStack(spacing: 8) { CareIcon(name: "Stitch_print", color: CareTheme.text, size: 20); Text("In báo cáo trực tiếp").font(CareFont.subheadline.weight(.semibold)) }
                            .frame(maxWidth: .infinity, minHeight: 48).background(CareTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareTheme.border))
                    }.foregroundStyle(CareTheme.text)
                    #endif
                    if let error { Text(error).font(CareFont.subheadline).foregroundStyle(CareTheme.medical) }
                    HStack(alignment: .top, spacing: 10) {
                        CareIcon(name: "Stitch_health_and_safety", color: CareTheme.secondary, size: 18)
                        Text("Báo cáo do phụ huynh ghi nhận, phục vụ trao đổi với người chăm sóc hoặc bác sĩ. Không thay thế chẩn đoán của nhân viên y tế.").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                    }.padding(14).background(CareTheme.border.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    Text("Tạo lúc \(snapshot.createdAt.careFormatted(date: .abbreviated, time: .shortened)) · Bản chụp dữ liệu tại thời điểm tạo")
                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary).frame(maxWidth: .infinity)
                }.padding(20)
            } else { ProgressView("Đang chuẩn bị bản xem trước…").padding(40) }
        }
        .background(CareTheme.background).foregroundStyle(CareTheme.text)
        .navigationTitle("Xem trước báo cáo").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if snapshot == nil { snapshot = CareReportSnapshot(viewModel: viewModel, interval: InsightRange.hours48.interval(), sections: Set(ReportSection.allCases)) }
        }
    }

    private func summaryCard(_ report: CareReportSnapshot) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                if report.includeProfile {
                    HStack(spacing: 12) {
                        CareIcon(name: "Stitch_child_care", color: CareTheme.accent, size: 28).padding(12).background(CareTheme.accent.opacity(0.06), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(report.baby.name).font(CareFont.title2.bold())
                            Text(report.baby.ageDescription).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
                            if report.includeBirthDate { Text("\(report.baby.birthDate.careFormatted(date: .abbreviated, time: .omitted)) · \(report.baby.gender.title)").font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                        }
                    }
                }
                Text("KHOẢNG THEO DÕI").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                Text(InsightData.intervalLabel(report.interval)).font(CareFont.subheadline.weight(.semibold))
                if report.sections.contains(.medical) {
                    HStack(alignment: .top, spacing: 10) {
                        reportStat("Thân nhiệt mới nhất", value: report.newestTemperature, color: CareTheme.medical)
                        reportStat("Hoạt động y tế", value: "\(report.activities.filter { $0.kind.group == .medical }.count) ghi nhận", color: CareTheme.accent)
                    }
                }
                if !report.illnessTitle.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        CareIcon(name: "Stitch_clinical_notes", color: CareTheme.routine, size: 20)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TÌNH TRẠNG ĐANG THEO DÕI").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.routine)
                            Text(report.illnessTitle).font(CareFont.subheadline.weight(.medium))
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(CareTheme.routineBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func medicalCard(_ report: CareReportSnapshot) -> some View {
        let points = report.temperatureActivities.sorted { $0.date < $1.date }
        let selected = selectedDate.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) } }
        return CareCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CareIcon(name: "Stitch_show_chart", color: CareTheme.medical, size: 20)
                    Text("Diễn biến thân nhiệt").font(CareFont.headline)
                    Spacer()
                    Button { chartList.toggle() } label: { CareIcon(name: chartList ? "Stitch_show_chart" : "Stitch_format_list_bulleted", color: CareTheme.accent, size: 20) }
                        .frame(minWidth: 44, minHeight: 44).accessibilityLabel(chartList ? "Xem biểu đồ" : "Xem dạng danh sách")
                }
                if points.isEmpty { Text("Chưa ghi nhận nhiệt độ trong khoảng này").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary) }
                else if chartList {
                    ForEach(points) { item in InsightActivityRow(activity: item) }
                } else {
                    Text("Cao nhất đã ghi: \(report.highestTemperature)").font(CareFont.caption).foregroundStyle(CareTheme.medical)
                    Chart(points) { item in
                        if let value = InsightData.number(item.value) {
                            LineMark(x: .value("Thời điểm", item.date), y: .value("°C", value)).foregroundStyle(CareTheme.medical).interpolationMethod(.linear)
                            PointMark(x: .value("Thời điểm", item.date), y: .value("°C", value)).foregroundStyle(CareTheme.medical).symbolSize(item.id == selected?.id ? 85 : 35)
                        }
                    }.frame(height: 175).chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.day().month().hour()) } }
                    .chartXSelection(value: $selectedDate)
                    if let selected { Text("\(selected.date.careFormatted(date: .abbreviated, time: .shortened)) · \(selected.value) °C").font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.accent) }
                }
                HStack(spacing: 8) { CareIcon(name: "Stitch_medication", color: CareTheme.accent, size: 18); Text("Nhật ký dùng thuốc").font(CareFont.subheadline.weight(.semibold)) }
                if report.medicineActivities.isEmpty { Text("Chưa ghi nhận dùng thuốc").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary) }
                ForEach(report.medicineActivities) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        InsightActivityRow(activity: item)
                        if !item.note.isEmpty { Text(item.note).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                    }.padding(10).background(CareTheme.accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }
                ForEach(report.activities.filter { $0.kind.group == .medical && $0.kind != .temperature && $0.kind != .medicine }) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        InsightActivityRow(activity: item)
                        if !item.note.isEmpty { Text(item.note).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                    }
                }
            }
        }
    }

    private func nutritionCard(_ report: CareReportSnapshot) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: 16) {
                CareSectionTitle(title: "Dinh dưỡng & Sinh hoạt")
                HStack(alignment: .top, spacing: 10) {
                    if report.sections.contains(.feeding) {
                        reportStat("TỔNG SỮA ĐÃ GHI", value: InsightData.sum(report.activities, kind: .milk, unit: "ml").map { "\(InsightData.format($0)) ml" } ?? "Chưa ghi nhận", color: CareTheme.feeding)
                    }
                    if report.sections.contains(.routine) {
                        reportStat("GIẤC NGỦ ĐÃ KẾT THÚC", value: InsightData.sleepHours(report.activities, in: report.interval).map { "\(InsightData.format($0)) giờ" } ?? "Chưa ghi nhận", color: CareTheme.routine)
                    }
                }
                if report.sections.contains(.feeding) { Text("Lượng ml chưa gồm bú mẹ trực tiếp.").font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                ForEach(report.activities.filter { $0.kind.group != .medical }) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        InsightActivityRow(activity: item)
                        if !item.note.isEmpty { Text(item.note).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
                    }
                }
            }
        }
    }

    private func growthCard(_ report: CareReportSnapshot) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: 12) {
                CareSectionTitle(title: "Số đo cơ thể")
                if report.measurements.isEmpty { Text("Chưa có số đo trong khoảng này").font(CareFont.subheadline).foregroundStyle(CareTheme.secondary) }
                ForEach(report.measurements) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.date, format: .dateTime.day().month().year()).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        Text([item.weight.map { "\(InsightData.format($0)) kg" }, item.height.map { "\(InsightData.format($0)) cm" }].compactMap { $0 }.joined(separator: " · ")).font(CareFont.headline)
                    }
                }
            }
        }
    }
    private func reportStat(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(CareFont.caption).foregroundStyle(CareTheme.secondary); Text(value).font(CareFont.headline).foregroundStyle(color) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
    private func createPDF(_ report: CareReportSnapshot) {
        do { exportURL = try CareReportPDF.create(report); error = nil }
        catch { self.error = "Chưa tạo được PDF. Hãy thử lại." }
    }
    #if canImport(UIKit)
    private func printReport(_ report: CareReportSnapshot) {
        if exportURL == nil { createPDF(report) }
        guard let exportURL else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "Báo cáo Bé Khỏe"
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = exportURL
        controller.present(animated: true, completionHandler: nil)
    }
    #endif
}

#Preview { NavigationStack { ReportPreviewView() }.environment(BabyCareViewModel.preview()) }
