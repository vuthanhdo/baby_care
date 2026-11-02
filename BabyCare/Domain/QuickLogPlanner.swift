import Foundation

/// What to save for a widget tap or the "Ghi cho bé" shortcut, built from the selected baby's data the
/// same way the Quick log screen builds it. Pure: the caller commits the mutation through the view model.
nonisolated enum QuickLogPlanner {
    struct Plan: Equatable {
        var mutation: CareDataMutation
        /// The confirmation, such as "Đã lưu sữa 120 ml".
        var message: String
    }

    /// The kinds the shortcut's form can log.
    enum FormKind: String, CaseIterable, Sendable {
        case milk, water, diaper, temperature, meal, bath, sleep, other
    }

    /// One-tap widget actions: a diaper change, the last feed repeated now, or the start or end of a sleep.
    static func plan(_ action: QuickLogAction, baby: BabyData, now: Date = Date()) throws -> Plan {
        let babyID = baby.profile.id
        switch action {
        case .diaper:
            let entry = CareActivity(kind: .diaper, date: now, value: "Thay tã")
            return Plan(mutation: .saveActivities(babyID: babyID, entries: [entry]), message: saved(entry))
        case .milk:
            guard let last = baby.activities.first(where: { $0.kind == .milk }) else {
                throw CareDataError.invalidInput(L10n.text("Chưa có cữ sữa nào để lặp lại. Hãy ghi cữ đầu tiên trong app."))
            }
            let entry = CareActivity(kind: .milk, date: now, value: last.value, unit: last.unit, detail: last.detail)
            return Plan(mutation: .saveActivities(babyID: babyID, entries: [entry]), message: saved(entry))
        case .sleep:
            return try sleep(baby: baby, now: now)
        }
    }

    /// The shortcut's form. `amount` is in ml for milk and water and °C for a temperature; `content` is the
    /// diaper choice, the food, or what happened for "other"; `note` is free text.
    static func plan(_ kind: FormKind, amount: Double?, content: String?, note: String?, baby: BabyData, now: Date = Date()) throws -> Plan {
        let babyID = baby.profile.id
        let content = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var entry: CareActivity
        switch kind {
        case .sleep:
            return try sleep(baby: baby, now: now)
        case .milk, .water, .temperature:
            guard let amount, amount.isFinite, amount > 0 else { throw CareDataError.invalidInput(L10n.text("Nhập số dương và đơn vị để lưu.")) }
            let activityKind: ActivityKind = kind == .milk ? .milk : kind == .water ? .water : .temperature
            entry = CareActivity(kind: activityKind, date: now, value: format(amount), unit: activityKind.defaultUnit, note: note)
            if kind == .temperature { entry.detail = "Chưa rõ" }
            // A bottle keeps the type of milk of the last bottle; breastfeeding is timed, not measured, so it falls back to formula.
            if kind == .milk {
                let last = baby.activities.first { $0.kind == .milk && $0.unit == "ml" }
                entry.detail = last?.detail ?? "Sữa công thức"
            }
        case .diaper:
            entry = CareActivity(kind: .diaper, date: now, value: content.isEmpty ? "Thay tã" : content, note: note)
        case .meal:
            entry = CareActivity(kind: .meal, date: now, value: content.isEmpty ? CareActivity.recordedValue : content, note: note)
        case .bath:
            entry = CareActivity(kind: .bath, date: now, value: CareActivity.recordedValue, note: note)
        case .other:
            guard !content.isEmpty else { throw CareDataError.invalidInput(L10n.text("Nhập nội dung hoạt động để lưu.")) }
            entry = CareActivity(kind: .other, date: now, value: content, note: note)
        }
        try CareValidation.activity(entry)
        return Plan(mutation: .saveActivities(babyID: babyID, entries: [entry]), message: saved(entry))
    }

    /// Starts a sleep, or ends the running one as the sleep card's "Kết thúc" does.
    private static func sleep(baby: BabyData, now: Date) throws -> Plan {
        let babyID = baby.profile.id
        guard let start = baby.sleepStartDate else {
            return Plan(mutation: .startSleep(babyID: babyID, date: now), message: L10n.text("Đã bắt đầu tính giờ ngủ"))
        }
        let minutes = max(1, Int((now.timeIntervalSince(start) / 60).rounded(.towardZero)))
        let entry = CareActivity(kind: .sleep, date: start, value: String(minutes), unit: "phút", detail: "Giấc ngủ")
        return Plan(mutation: .saveActivities(babyID: babyID, entries: [entry], finishingSleep: start), message: saved(entry))
    }

    /// "Đã lưu sữa 120 ml", "Đã lưu đi tiểu", "Đã lưu tắm bé".
    private static func saved(_ entry: CareActivity) -> String {
        let value = entry.formattedValue
        let title = entry.kind.title.lowercased()
        let text = entry.kind == .diaper ? value.lowercased() : value == L10n.text(CareActivity.recordedValue) ? title : "\(title) \(value)"
        return L10n.text("Đã lưu {0}", text)
    }

    /// Whole numbers stay whole ("120"); a temperature keeps one decimal in the app's language ("37,5").
    static func format(_ amount: Double) -> String {
        amount.formatted(.number.grouping(.never).precision(.fractionLength(0...1)).locale(AppLanguage.current.locale))
    }
}
