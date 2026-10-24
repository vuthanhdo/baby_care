import Foundation
import Observation

struct ActivityFormState {
    var value = ""
    var unit = ""
    var date = Date()
    var note = ""
    var detail = ""
    var symptoms: Set<String> = []
    /// Second-level choice per ticked symptom, e.g. "Ho" → "khan".
    var symptomVariants: [String: String] = [:]
    var allergy = AllergyNote()
    var followUpDate: Date?
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
    case symptomVariant(String, String)
    case allergy(AllergyNote)
    /// Sets the duration so the sleep ends at this moment.
    case sleepEnd(Date)
    case followUp(Date?)
    case attachments([Data])
    case loadingPhotos(Bool)
    case adjust(Double)
}

@MainActor @Observable
final class ActivityFormViewModel {
    private(set) var state: ActivityFormState
    let kind: ActivityKind
    let id: UUID

    init(kind: ActivityKind, activity: CareActivity? = nil, now: Date = Date()) {
        self.kind = kind
        id = activity?.id ?? UUID()
        let choices = kind == .symptom ? SymptomCatalog.parse(activity?.value ?? "") : []
        // A sleep logged afterwards starts as "the last hour"; both ends can then be moved back.
        let value = switch kind {
        case .allergy: ""
        case .meal: activity.map(MealEntry.food) ?? ""
        case .sleep: activity?.value ?? "60"
        default: activity?.value ?? ""
        }
        state = ActivityFormState(value: value, unit: activity?.unit ?? kind.defaultUnit,
            date: activity?.date ?? (kind == .sleep ? now.addingTimeInterval(-3600) : now), note: activity?.note ?? "",
            detail: activity?.detail ?? (kind == .temperature ? "Chưa rõ" : kind == .milk ? "Sữa công thức" : kind == .breathing ? "Chưa rõ" : ""),
            symptoms: Set(choices.map(\.name)),
            symptomVariants: Dictionary(choices.filter { !$0.variant.isEmpty }.map { ($0.name, $0.variant) }, uniquingKeysWith: { first, _ in first }),
            allergy: kind == .allergy ? AllergyNote(line: activity?.value ?? "") : AllergyNote(),
            followUpDate: kind == .doctor ? activity?.followUpDate : nil,
            attachments: activity?.attachments ?? [])
    }

    func send(_ action: ActivityFormAction) {
        switch action {
        case .value(let value): state.value = value
        case .unit(let value): state.unit = value
        case .date(let value):
            // Moving the start of a sleep keeps its end where it was.
            let end = tracksSleepEnd ? sleepEnd : nil
            state.date = value
            if let end { setSleepEnd(end) }
        case .sleepEnd(let end): setSleepEnd(end)
        case .followUp(let value): state.followUpDate = value
        case .note(let value): state.note = value
        case .symptoms(let value):
            state.symptoms = value
            state.symptomVariants = state.symptomVariants.filter { value.contains($0.key) }
        case .symptomVariant(let name, let variant): state.symptomVariants[name] = variant.isEmpty ? nil : variant
        case .allergy(let value): state.allergy = value
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
            state.value = max(0.1, number + amount).formatted(.number.grouping(.never).precision(.fractionLength(1)).locale(AppLanguage.current.locale))
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
    var numeric: Bool { ActivityKind.numericKinds.contains(kind) }
    var number: Double? { Double(value.replacingOccurrences(of: ",", with: ".")) }
    /// Sleeps are entered as a start and an end; old point-in-time records keep their single moment.
    var tracksSleepEnd: Bool { kind == .sleep && detail != CareActivity.recordedSleepDetail }
    var sleepEnd: Date? { number.map { date.addingTimeInterval($0 * 60) } }
    private func setSleepEnd(_ end: Date) {
        let minutes = Int((end.timeIntervalSince(state.date) / 60).rounded())
        state.value = minutes > 0 ? String(minutes) : ""
    }
    var valid: Bool {
        guard date <= Date(), !state.loadingPhotos else { return false }
        if let followUp = state.followUpDate, followUp <= date { return false }
        if numeric {
            guard let number, number.isFinite, number > 0 else { return false }
            if kind == .medicine && ((detail.trimmingCharacters(in: .whitespaces).isEmpty && attachments.isEmpty) || unit.isEmpty) { return false }
            if kind == .breathing && number > BreathingReference.maximum { return false }
            if tracksSleepEnd && date.addingTimeInterval(number * 60) > Date().addingTimeInterval(60) { return false }
        } else if kind == .symptom {
            return !symptoms.isEmpty && (!symptoms.contains("Khác") || !detail.trimmingCharacters(in: .whitespaces).isEmpty)
        } else if kind == .allergy {
            return !state.allergy.trimmed.name.isEmpty
        } else if ![.bath, .diaper, .meal].contains(kind) && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }
    var validationMessage: String {
        if loadingPhotos { return L10n.text("Đang tải ảnh…") }
        if kind == .medicine && detail.isEmpty && attachments.isEmpty { return L10n.text("Nhập tên thuốc hoặc thêm ảnh thuốc, kèm lượng đã dùng.") }
        if kind == .symptom { return L10n.text("Chọn ít nhất một triệu chứng; mô tả nếu chọn Khác.") }
        if kind == .allergy { return L10n.text("Nhập tên chất hoặc tác nhân gây dị ứng.") }
        if kind == .breathing { return L10n.text("Nhập số nhịp thở đếm được trong 1 phút (1–150).") }
        if let followUp = state.followUpDate, followUp <= date { return L10n.text("Lịch khám lại phải sau ngày khám.") }
        if kind == .sleep { return L10n.text("Giờ kết thúc phải sau giờ bắt đầu và không ở tương lai.") }
        return numeric ? L10n.text("Nhập {0} bằng số dương để lưu.", "\(kind.title.lowercased())") : L10n.text("Nhập nội dung hoạt động để lưu.")
    }

    func makeEntry() -> CareActivity? {
        guard valid else { return nil }
        let value = switch kind {
        case .symptom: SymptomCatalog.format(symptoms.map { SymptomChoice(name: $0, variant: state.symptomVariants[$0] ?? "") })
        case .allergy: state.allergy.trimmed.line
        default: value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return CareActivity(id: id, kind: kind, date: date, value: value.isEmpty ? CareActivity.recordedValue : value,
            unit: [.meal, .doctor].contains(kind) ? unit.trimmingCharacters(in: .whitespacesAndNewlines) : unit, note: note, detail: detail, attachments: attachments,
            followUpDate: kind == .doctor ? state.followUpDate : nil)
    }
}
