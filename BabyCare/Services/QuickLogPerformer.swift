import Foundation

/// Runs widget taps and the "Ghi cho bé" shortcut inside the app. The system may launch the app in the
/// background for them, so this waits for the shared session to open the account's family (or device storage)
/// as a launch does, then saves through that view model: same validation, cloud outbox, reminders and roles.
@MainActor enum QuickLogPerformer {
    static func perform(_ action: QuickLogAction) async {
        do {
            let (model, baby) = try await readyModel()
            try await commit(QuickLogPlanner.plan(action, baby: baby), on: model)
        } catch {
            CareWidgetPublisher().show(notice: error.localizedDescription)
        }
    }

    /// Returns the confirmation the shortcut speaks or shows, such as "Đã lưu sữa 120 ml cho Bé Sóc".
    static func perform(_ kind: QuickLogPlanner.FormKind, amount: Double?, content: String?, note: String?) async throws -> String {
        let (model, baby) = try await readyModel()
        let plan = try QuickLogPlanner.plan(kind, amount: amount, content: content, note: note, baby: baby)
        try await commit(plan, on: model)
        return L10n.text("{0} cho {1}", plan.message, baby.profile.name)
    }

    private static func commit(_ plan: QuickLogPlanner.Plan, on model: BabyCareViewModel) async throws {
        // A save started on screen finishes first; the view model refuses a second one meanwhile.
        try await wait(timeout: 10) { !model.state.isSaving }
        guard await model.send(.commit(plan.mutation, message: plan.message)) else {
            let message = model.state.error ?? L10n.text("Hãy thử lại.")
            // The reason goes to the widget or the shortcut; the app should not greet the parent with it later.
            await model.send(.dismissError)
            throw QuickLogError.message(message)
        }
    }

    private static func readyModel() async throws -> (BabyCareViewModel, BabyData) {
        let session = SessionViewModel.shared
        session.start()
        var model: BabyCareViewModel?
        try await wait(timeout: 20) {
            switch session.phase {
            case .starting: return false
            case .content: model = session.viewModel; return model != nil
            case .signedOut: throw QuickLogError.signedOut
            case .consent: throw QuickLogError.consent
            case .accountError: throw QuickLogError.message(session.error ?? L10n.text("Hãy thử lại."))
            }
        }
        guard let model else { throw QuickLogError.timeout }
        if model.state.phase != .ready {
            try await wait(timeout: 20) { model.state.phase != .loading && !model.state.isRefreshing }
            if model.state.phase != .ready, !(await model.send(.load)) {
                let message = model.state.error ?? L10n.text("Hãy thử lại.")
                await model.send(.dismissError)
                throw QuickLogError.message(message)
            }
        }
        guard model.hasOnboarded, let baby = model.state.database.selectedBaby else { throw QuickLogError.noBaby }
        return (model, baby)
    }

    private static func wait(timeout: TimeInterval, until condition: () throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while try !condition() {
            guard Date() < deadline else { throw QuickLogError.timeout }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}

nonisolated enum QuickLogError: Error, LocalizedError, Equatable {
    case signedOut, consent, noBaby, timeout
    case message(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: L10n.text("Hãy mở Bé Khỏe và đăng nhập trước.")
        case .consent: L10n.text("Hãy mở Bé Khỏe để xác nhận quyền riêng tư trước.")
        case .noBaby: L10n.text("Hãy mở Bé Khỏe để tạo hồ sơ bé trước.")
        case .timeout: L10n.text("Chưa mở được dữ liệu của bé. Hãy thử lại.")
        case .message(let text): text
        }
    }
}
