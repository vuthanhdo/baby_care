import Foundation
import Observation

enum BabyCareAction {
    case load
    case commit(CareDataMutation, message: String? = nil)
    case showMessage(String)
    case dismissError
}

struct BabyCareState {
    enum Phase { case idle, loading, ready, failed }
    var database = CareDatabase()
    var phase: Phase = .idle
    var isSaving = false
    var error: String?
    var toast: String?
    var storage: CareStorageStatus = .device
    var vaccinationsAvailable = true
    var requiresConsent = false
}

/// The single owner of shared UI state. Views dispatch actions and read snapshots.
@MainActor @Observable
final class BabyCareViewModel {
    private(set) var state = BabyCareState()
    let isDemo: Bool
    /// Bumped when it is a good moment to ask for an App Store rating; the root view asks StoreKit.
    private(set) var reviewRequests = 0
    @ObservationIgnored private let provider: any CareDataProvider
    @ObservationIgnored private let reviews: CareReviewTracker?
    @ObservationIgnored private let notifications: any CareReminderService
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private let emptyProfile = BabyProfile()
    @ObservationIgnored private var active = true

    init(provider: any CareDataProvider, notifications: (any CareReminderService)? = nil,
         initialData: CareDatabase? = nil, isDemo: Bool = false, reviews: CareReviewTracker? = nil) {
        self.provider = provider
        self.notifications = notifications ?? NoopCareReminderService()
        self.reviews = reviews
        self.isDemo = isDemo
        if let initialData { state.database = initialData; state.phase = .ready }
    }

    var baby: BabyProfile { state.database.selectedBaby?.profile ?? emptyProfile }
    var babies: [BabyProfile] { state.database.babies.map(\.profile) }
    var hasOnboarded: Bool { state.database.hasOnboarded }
    var activities: [CareActivity] { state.database.selectedBaby?.activities ?? [] }
    var vaccinations: [VaccinationRecord] { state.database.selectedBaby?.vaccinations ?? [] }
    var measurements: [BodyMeasurement] { state.database.selectedBaby?.measurements ?? [] }
    var medicationReminders: [MedicationReminder] { state.database.selectedBaby?.medicationReminders ?? [] }
    var isTrackingIllness: Bool { state.database.selectedBaby?.isTrackingIllness ?? false }
    var illnessTitle: String { state.database.selectedBaby?.illnessTitle ?? "" }
    var illnessStartDate: Date { state.database.selectedBaby?.illnessStartDate ?? baby.birthDate }
    var sleepStartDate: Date? { state.database.selectedBaby?.sleepStartDate }
    var toast: String? { state.toast }

    @discardableResult
    func send(_ action: BabyCareAction) async -> Bool {
        guard active else { return false }
        switch action {
        case .showMessage(let message): showMessage(message); return true
        case .dismissError: state.error = nil; return true
        case .load:
            guard !state.isSaving, state.phase != .loading else { return false }
            let wasReady = state.phase == .ready
            state.phase = .loading
            state.error = nil
            do {
                let previous = state.database
                let loaded = try await provider.load()
                guard active else { return false }
                let storage = await provider.status()
                guard active else { return false }
                let vaccinationsAvailable = await provider.supportsVaccinations()
                guard active else { return false }
                state.vaccinationsAvailable = vaccinationsAvailable
                state.database = loaded
                state.storage = storage
                state.phase = .ready
                if let notice = await provider.takeNotice() { state.error = notice }
                if let warning = await notifications.reconcile(previous: previous, current: loaded) { showMessage(warning) }
                guard active else { return false }
                return true
            } catch {
                guard active else { return false }
                if error as? CloudError == .consentRequired { state.requiresConsent = true }
                if error as? CloudError == .accessDenied || error as? CloudError == .signedOut {
                    state.database = CareDatabase(); state.phase = .failed
                    state.error = error.localizedDescription
                    await notifications.invalidate()
                    return false
                }
                state.phase = wasReady ? .ready : .failed
                state.error = error.localizedDescription
                return false
            }
        case .commit(let mutation, let message):
            guard state.phase == .ready, !state.isSaving else { return false }
            state.isSaving = true
            state.error = nil
            defer { state.isSaving = false }
            do {
                let previous = state.database
                let saved = try await provider.apply(mutation)
                guard active else { return false }
                let storage = await provider.status()
                guard active else { return false }
                state.database = saved
                state.storage = storage
                // Notifications are an effect after a durable commit, never part of a View.
                let warning = await notifications.reconcile(previous: previous, current: saved)
                guard active else { return false }
                if let message = warning ?? message { showMessage(message) }
                if let notice = await provider.takeNotice() { state.error = notice }
                if reviews?.didCommit(mutation) == true { reviewRequests += 1 }
                return true
            } catch {
                guard active else { return false }
                if error as? CloudError == .consentRequired { state.requiresConsent = true }
                let storage = await provider.status()
                guard active else { return false }
                state.storage = storage
                // A refused write is no longer shown; neither are later changes that depended on it.
                if let current = await provider.currentDatabase(), current != state.database {
                    let previous = state.database
                    state.database = current
                    _ = await notifications.reconcile(previous: previous, current: current)
                }
                state.error = error.localizedDescription
                return false
            }
        }
    }

    /// A moment outside a data change that may deserve a rating prompt, such as a shared report.
    func noteReviewMoment(_ moment: CareReviewPolicy.Moment) {
        if reviews?.ask(after: moment) == true { reviewRequests += 1 }
    }

    deinit { toastTask?.cancel() }

    func deactivate() async {
        active = false; toastTask?.cancel()
        state = BabyCareState()
        await notifications.invalidate()
        await provider.invalidate()
    }

    private func showMessage(_ message: String) {
        toastTask?.cancel()
        state.toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.state.toast = nil
        }
    }

    static func preview() -> BabyCareViewModel {
        let data = CarePreviewData.make()
        return BabyCareViewModel(provider: InMemoryCareDataProvider(database: data), initialData: data, isDemo: true)
    }
}
