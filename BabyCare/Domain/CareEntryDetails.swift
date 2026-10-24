import Foundation

// Structured parts of an entry are kept in the existing text columns (`value`, `unit`, `detail`, the profile's
// `allergies`) as readable Vietnamese, so the cloud contract stays the same and older app versions still show
// them as plain text. Each type below parses leniently: text it does not recognise is kept as written.

// MARK: - Symptoms

/// One ticked symptom with an optional second-level choice, stored as `Ho` or `Ho (khan)`.
nonisolated struct SymptomChoice: Hashable, Sendable {
    var name: String
    var variant = ""

    init(name: String, variant: String = "") {
        self.name = name
        self.variant = variant
    }

    /// Reads one stored token; a token that is not `<known symptom> (<text>)` stays a plain name.
    init(token: String) {
        if token.hasSuffix(")"), let open = token.range(of: " ("),
           SymptomCatalog.names.contains(String(token[..<open.lowerBound])) {
            name = String(token[..<open.lowerBound])
            variant = String(token[open.upperBound..<token.index(before: token.endIndex)])
        } else {
            name = token
        }
    }

    var token: String { variant.isEmpty ? name : "\(name) (\(variant))" }
    var displayName: String { variant.isEmpty ? L10n.text(name) : "\(L10n.text(name)) (\(L10n.text(variant)))" }
}

nonisolated enum SymptomCatalog {
    static let names = ["Sốt", "Ho", "Sổ mũi", "Nôn", "Tiêu chảy", "Phát ban", "Mệt", "Khác"]

    /// Second-level choices; none of them may contain ", " because the list is stored comma-separated.
    static func variants(for name: String) -> [String] {
        switch name {
        case "Sốt": ["dưới 24 giờ", "1–2 ngày", "3 ngày trở lên"]
        case "Ho": ["khan", "có đờm", "khò khè", "ông ổng"]
        case "Sổ mũi": ["nước trong", "nước đục / xanh", "nghẹt mũi"]
        case "Nôn": ["trớ sữa", "1–2 lần", "nhiều lần"]
        case "Tiêu chảy": ["phân lỏng", "toàn nước", "có nhầy / máu"]
        case "Phát ban": ["chấm đỏ", "mẩn ngứa", "mụn nước"]
        case "Mệt": ["quấy khóc", "li bì", "bỏ ăn / bú"]
        default: []
        }
    }

    /// The question shown above a symptom's choices.
    static func prompt(for name: String) -> String {
        switch name {
        case "Sốt": L10n.text("Sốt bao lâu?")
        case "Ho": L10n.text("Kiểu ho")
        case "Sổ mũi": L10n.text("Nước mũi")
        case "Nôn": L10n.text("Mức độ nôn")
        case "Tiêu chảy": L10n.text("Tính chất phân")
        case "Phát ban": L10n.text("Dạng ban")
        default: L10n.text("Biểu hiện")
        }
    }

    static func parse(_ value: String) -> [SymptomChoice] {
        value.components(separatedBy: ", ").filter { !$0.isEmpty }.map(SymptomChoice.init(token:))
    }

    /// Catalogue order first, then anything else alphabetically, so the same choices always store the same text.
    static func format(_ choices: some Collection<SymptomChoice>) -> String {
        choices.sorted { a, b in
            let ia = names.firstIndex(of: a.name) ?? names.count, ib = names.firstIndex(of: b.name) ?? names.count
            return ia == ib ? a.token < b.token : ia < ib
        }.map(\.token).joined(separator: ", ")
    }

    static func display(_ value: String) -> String { parse(value).map(\.displayName).joined(separator: ", ") }
}

// MARK: - Allergies

/// An allergy with how severe the reaction was and how sure the family is, stored as one line:
/// `Đậu phộng · Nặng · Đã xác nhận`. The profile keeps one line per allergy.
nonisolated struct AllergyNote: Equatable, Sendable {
    var name = ""
    /// Empty when unknown.
    var severity = ""
    var certainty = ""

    static let severities = ["Nhẹ", "Nặng"]
    /// No longer offered, but entries saved with it still read back as a severity.
    static let retiredSeverities = ["Vừa"]
    static let certainties = ["Nghi ngờ", "Khả năng cao", "Đã xác nhận"]

    init(name: String = "", severity: String = "", certainty: String = "") {
        self.name = name
        self.severity = severity
        self.certainty = certainty
    }

    /// Free text from earlier versions (or anything not in this shape) becomes the name, unchanged.
    init(line: String) {
        let parts = line.components(separatedBy: " · ")
        var note = AllergyNote(name: parts[0])
        for part in parts.dropFirst() {
            if note.severity.isEmpty, (Self.severities + Self.retiredSeverities).contains(part) { note.severity = part }
            else if note.certainty.isEmpty, Self.certainties.contains(part) { note.certainty = part }
            else { self = AllergyNote(name: line); return }
        }
        self = note
    }

    var trimmed: AllergyNote {
        AllergyNote(name: name.trimmingCharacters(in: .whitespacesAndNewlines), severity: severity, certainty: certainty)
    }
    var line: String { [name, severity, certainty].filter { !$0.isEmpty }.joined(separator: " · ") }
    var displayText: String { [name, L10n.text(severity), L10n.text(certainty)].filter { !$0.isEmpty }.joined(separator: " · ") }

    static func list(_ text: String) -> [AllergyNote] {
        text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(AllergyNote.init(line:))
    }
    static func text(_ notes: [AllergyNote]) -> String {
        notes.map(\.trimmed).filter { !$0.name.isEmpty }.map(\.line).joined(separator: "\n")
    }
    /// The profile's allergies for screens and reports, translated where the app knows the words.
    static func display(_ text: String, separator: String = "\n") -> String { list(text).map(\.displayText).joined(separator: separator) }
}

// MARK: - Temperature

/// Where and with what the temperature was taken, stored as `Nách` or `Nách · Điện tử`.
nonisolated struct TemperatureDetail: Equatable, Sendable {
    var site = "Chưa rõ"
    /// Empty when the parent did not say.
    var thermometer = ""

    static let sites = ["Chưa rõ", "Nách", "Hậu môn", "Tai", "Trán", "Khác"]
    static let thermometers = ["Điện tử", "Thủy ngân"]

    init(site: String = "Chưa rõ", thermometer: String = "") {
        self.site = site
        self.thermometer = thermometer
    }

    init(_ detail: String) {
        let parts = detail.components(separatedBy: " · ")
        if parts.count == 2, Self.thermometers.contains(parts[1]) {
            self.init(site: parts[0], thermometer: parts[1])
        } else {
            self.init(site: detail.isEmpty ? "Chưa rõ" : detail)
        }
    }

    var detail: String { thermometer.isEmpty ? site : "\(site) · \(thermometer)" }
    var displayText: String {
        thermometer.isEmpty ? L10n.text(site) : "\(L10n.text(site)) · \(L10n.text("Nhiệt kế {0}", L10n.text(thermometer).lowercased()))"
    }
}

/// Usual body temperature for each measuring site, for the info sheet next to the site picker.
nonisolated enum TemperatureReference {
    struct Row: Equatable, Sendable {
        let site: String
        let range: ClosedRange<Double>
    }
    /// Ranges widely quoted by Vietnamese hospitals (e.g. Vinmec); the forehead depends on the thermometer.
    static let rows = [
        Row(site: "Hậu môn", range: 36.6...38.0),
        Row(site: "Tai", range: 35.8...38.0),
        Row(site: "Miệng", range: 35.5...37.5),
        Row(site: "Nách", range: 34.7...37.3)
    ]
    static func row(for site: String) -> Row? { rows.first { $0.site == site } }
}

// MARK: - Meals

/// A meal is the food in `value` and the amount, as the parent wrote it, in `unit`; both are optional.
nonisolated enum MealEntry {
    static func food(_ activity: CareActivity) -> String { activity.value == CareActivity.recordedValue ? "" : activity.value }
    static func amount(_ activity: CareActivity) -> String { activity.unit }
}

// MARK: - Breathing

/// WHO IMCI cut-offs for fast breathing by age; counted for a full minute while the child is calm.
nonisolated enum BreathingReference {
    struct Band: Equatable, Sendable {
        /// Ages in whole months, upper bound excluded.
        let months: Range<Int>
        let title: String
        /// Breaths per minute from which WHO counts breathing as fast.
        let fastFrom: Int
    }
    static let bands = [
        Band(months: 0..<2, title: "Dưới 2 tháng", fastFrom: 60),
        Band(months: 2..<12, title: "2 đến 12 tháng", fastFrom: 50),
        Band(months: 12..<60, title: "1 đến 5 tuổi", fastFrom: 40)
    ]
    static func band(birthDate: Date, at date: Date, calendar: Calendar = .current) -> Band? {
        let months = calendar.dateComponents([.month], from: birthDate, to: date).month ?? 0
        return bands.first { $0.months.contains(max(0, months)) }
    }
    static let states = ["Lúc ngủ", "Lúc thức, nằm yên", "Chưa rõ"]
    static let maximum = 150.0
}

// MARK: - Doctor visits

/// A visit keeps the reason in `value`, the doctor's diagnosis in `unit`, the advice in `detail` and the
/// follow-up appointment in `followUpDate`.
nonisolated enum DoctorVisit {
    static func diagnosis(_ activity: CareActivity) -> String { activity.kind == .doctor ? activity.unit : "" }
}

/// A visit's follow-up appointment is reminded this long before it.
nonisolated enum DoctorFollowUp {
    static let reminderLead: TimeInterval = 2 * 86_400
    static func reminderDate(for appointment: Date) -> Date { appointment.addingTimeInterval(-reminderLead) }
    /// A week after the visit at 8:00, the starting suggestion when the parent turns the appointment on.
    static func suggestedDate(after visit: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: visit.addingTimeInterval(7 * 86_400))
        return calendar.date(byAdding: .hour, value: 8, to: day) ?? visit.addingTimeInterval(7 * 86_400)
    }
    /// The nearest appointment still ahead within `days`, for the home screen.
    static func upcoming(in activities: [CareActivity], now: Date = Date(), within days: Double = 14) -> CareActivity? {
        activities.filter { $0.kind == .doctor && ($0.followUpDate.map { $0 > now && $0 <= now.addingTimeInterval(days * 86_400) } ?? false) }
            .min { ($0.followUpDate ?? .distantFuture) < ($1.followUpDate ?? .distantFuture) }
    }
}

// MARK: - Sleep

/// Recommended sleep per 24 hours including naps: WHO (2019) for under-fives, AASM (2016) from 6 years.
nonisolated enum SleepRecommendation {
    struct Band: Equatable, Sendable {
        let months: Range<Int>
        let title: String
        let hours: ClosedRange<Int>
    }
    static let bands = [
        Band(months: 0..<4, title: "0–3 tháng", hours: 14...17),
        Band(months: 4..<12, title: "4–11 tháng", hours: 12...16),
        Band(months: 12..<36, title: "1–2 tuổi", hours: 11...14),
        Band(months: 36..<72, title: "3–5 tuổi", hours: 10...13),
        Band(months: 72..<156, title: "6–12 tuổi", hours: 9...12)
    ]
    static func band(birthDate: Date, at date: Date = Date(), calendar: Calendar = .current) -> Band? {
        let months = calendar.dateComponents([.month], from: birthDate, to: date).month ?? 0
        return bands.first { $0.months.contains(max(0, months)) }
    }
    static func text(_ band: Band) -> String {
        L10n.text("{0}–{1} giờ/ngày", "\(band.hours.lowerBound)", "\(band.hours.upperBound)")
    }
}
