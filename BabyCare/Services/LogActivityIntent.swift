import AppIntents

/// "Ghi cho bé": logs for the selected baby without opening the app. Siri, Spotlight, the Action button or a
/// Shortcuts icon on the Home Screen ask for what is missing (the activity, then the amount or the diaper content)
/// in the system's own dialogs; the app runs in the background and saves through `QuickLogPerformer`.
struct LogActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi cho bé"
    static let description = IntentDescription("Ghi một hoạt động cho bé đang chọn trong Bé Khỏe mà không cần mở app.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Loại hoạt động", requestValueDialog: "Ghi hoạt động nào?")
    var kind: LogActivityKind
    @Parameter(title: "Lượng")
    var amount: Double?
    @Parameter(title: "Nội dung tã")
    var diaper: DiaperContent?
    @Parameter(title: "Nội dung")
    var content: String?
    @Parameter(title: "Ghi chú")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Ghi \(\.$kind) cho bé") {
            \.$amount
            \.$diaper
            \.$content
            \.$note
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch kind {
        case .milk where amount == nil, .water where amount == nil: throw $amount.needsValueError("Bao nhiêu ml?")
        case .temperature where amount == nil: throw $amount.needsValueError("Nhiệt độ bao nhiêu °C?")
        case .diaper where diaper == nil: throw $diaper.needsValueError("Tã thế nào?")
        case .meal where content == nil: throw $content.needsValueError("Bé ăn gì?")
        case .other where content == nil: throw $content.needsValueError("Hoạt động gì?")
        default: break
        }
        let message = try await QuickLogPerformer.perform(kind.formKind, amount: amount,
                                                          content: kind == .diaper ? diaper?.rawValue : content, note: note)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

nonisolated enum LogActivityKind: String, AppEnum {
    case milk, water, diaper, temperature, meal, bath, sleep, other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Loại hoạt động"
    static let caseDisplayRepresentations: [LogActivityKind: DisplayRepresentation] = [
        .milk: DisplayRepresentation(title: "Sữa", image: .init(systemName: "waterbottle")),
        .water: DisplayRepresentation(title: "Nước", image: .init(systemName: "drop")),
        .diaper: DisplayRepresentation(title: "Thay tã / Vệ sinh", image: .init(systemName: "figure.child")),
        .temperature: DisplayRepresentation(title: "Nhiệt độ", image: .init(systemName: "thermometer.medium")),
        .meal: DisplayRepresentation(title: "Bữa ăn", image: .init(systemName: "fork.knife")),
        .bath: DisplayRepresentation(title: "Tắm bé", image: .init(systemName: "bathtub")),
        .sleep: DisplayRepresentation(title: "Ngủ / Thức dậy", image: .init(systemName: "moon.zzz")),
        .other: DisplayRepresentation(title: "Hoạt động khác", image: .init(systemName: "square.and.pencil"))
    ]

    var formKind: QuickLogPlanner.FormKind {
        switch self {
        case .milk: .milk
        case .water: .water
        case .diaper: .diaper
        case .temperature: .temperature
        case .meal: .meal
        case .bath: .bath
        case .sleep: .sleep
        case .other: .other
        }
    }
}

/// Raw values are the stored diaper contents, the same choices as the activity form.
nonisolated enum DiaperContent: String, AppEnum {
    case change = "Thay tã", pee = "Đi tiểu", poo = "Đi ngoài", both = "Cả hai"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Nội dung tã"
    static let caseDisplayRepresentations: [DiaperContent: DisplayRepresentation] = [
        .change: "Thay tã", .pee: "Đi tiểu", .poo: "Đi ngoài", .both: "Cả hai"
    ]
}

struct BabyCareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogActivityIntent(), phrases: [
            "Ghi cho bé trong \(.applicationName)",
            "Log for my baby in \(.applicationName)",
            "\(.applicationName) log"
        ], shortTitle: "Ghi cho bé", systemImageName: "plus.circle")
    }
}
