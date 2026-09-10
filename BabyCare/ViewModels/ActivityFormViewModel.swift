import Foundation
import Observation

struct ActivityFormState {
    var value = ""
    var unit = ""
    var date = Date()
    var note = ""
    var detail = ""
    var symptoms: Set<String> = []
    var attachments: [Data] = []
    var loadingPhotos = false
    var dirty = false
}

enum ActivityFormAction {
    case value(String)
    case unit(String)
    case date(Date)
    case note(String)
    case detail(String)
    case symptoms(Set<String>)
    case attachments([Data])
    case loadingPhotos(Bool)
    case adjust(Double)
}

@MainActor @Observable
final class ActivityFormViewModel {
    private(set) var state: ActivityFormState
    let kind: ActivityKind
    let id: UUID

    init(kind: ActivityKind, activity: CareActivity? = nil) {
        self.kind = kind
        id = activity?.id ?? UUID()
        state = ActivityFormState(value: activity?.value ?? "", unit: activity?.unit ?? kind.defaultUnit,
            date: activity?.date ?? Date(), note: activity?.note ?? "",
            detail: activity?.detail ?? (kind == .temperature ? "Chưa rõ" : kind == .milk ? "Sữa công thức" : ""),
            symptoms: kind == .symptom ? Set(activity?.value.components(separatedBy: ", ") ?? []) : [],
            attachments: activity?.attachments ?? [])
    }

    func send(_ action: ActivityFormAction) {
        switch action {
        case .value(let value): state.value = value
        case .unit(let value): state.unit = value
        case .date(let value): state.date = value
        case .note(let value): state.note = value
        case .symptoms(let value): state.symptoms = value
        case .attachments(let value): state.attachments = value
        case .loadingPhotos(let value): state.loadingPhotos = value
        case .detail(let value):
            if kind == .milk && state.detail != value {
                state.unit = value == "Bú mẹ" ? "phút" : "ml"
                state.value = ""
            }
            state.detail = value
        case .adjust(let amount):
            guard let number else { return }
            state.value = max(0.1, number + amount).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "vi_VN")))
        }
        if case .loadingPhotos = action { return }
        state.dirty = true
    }

    private var value: String { state.value }
    private var unit: String { state.unit }
    private var date: Date { state.date }
    private var note: String { state.note }
    private var detail: String { state.detail }
    private var symptoms: Set<String> { state.symptoms }
    private var attachments: [Data] { state.attachments }
    private var loadingPhotos: Bool { state.loadingPhotos }
    var numeric: Bool { [.temperature, .medicine, .milk, .water, .sleep].contains(kind) }
    var number: Double? { Double(value.replacingOccurrences(of: ",", with: ".")) }
    var valid: Bool {
        guard date <= Date(), !state.loadingPhotos else { return false }
        if numeric {
            guard let number, number.isFinite, number > 0 else { return false }
            if kind == .medicine && (detail.trimmingCharacters(in: .whitespaces).isEmpty || unit.isEmpty) { return false }
            if kind == .sleep && detail != CareActivity.recordedSleepDetail && date.addingTimeInterval(number * 60) > Date().addingTimeInterval(60) { return false }
        } else if kind == .symptom {
            return !symptoms.isEmpty && (!symptoms.contains("Khác") || !detail.trimmingCharacters(in: .whitespaces).isEmpty)
        } else if ![.bath, .diaper].contains(kind) && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }
    var validationMessage: String {
        if loadingPhotos { return "Đang tải ảnh…" }
        if kind == .medicine && detail.isEmpty { return "Nhập tên thuốc và lượng thực tế đã dùng." }
        if kind == .symptom { return "Chọn ít nhất một triệu chứng; mô tả nếu chọn Khác." }
        if kind == .sleep { return "Nhập số phút; thời gian kết thúc không được ở tương lai." }
        return numeric ? "Nhập \(kind.title.lowercased()) bằng số dương để lưu." : "Nhập nội dung hoạt động để lưu."
    }

    func makeEntry() -> CareActivity? {
        guard valid else { return nil }
        let value = kind == .symptom ? symptoms.sorted().joined(separator: ", ") : value.trimmingCharacters(in: .whitespacesAndNewlines)
        return CareActivity(id: id, kind: kind, date: date, value: value.isEmpty ? "Đã ghi nhận" : value,
            unit: unit, note: note, detail: detail, attachments: attachments)
    }
}
