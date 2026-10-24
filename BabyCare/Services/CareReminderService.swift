import Foundation
import UserNotifications

@MainActor protocol CareReminderService {
    func reconcile(previous: CareDatabase, current: CareDatabase) async -> String?
    func invalidate() async
}
extension CareReminderService { func invalidate() async {} }

struct NoopCareReminderService: CareReminderService {
    func reconcile(previous: CareDatabase, current: CareDatabase) async -> String? { nil }
}

struct CareNotification: Equatable {
    var id: String
    var date: Date
}

@MainActor protocol CareNotificationCenter {
    func pendingIDs() async -> [String]
    func authorize() async throws -> Bool
    func add(_ notification: CareNotification) async throws
    func remove(_ ids: [String])
}

struct SystemCareNotificationCenter: CareNotificationCenter {
    func pendingIDs() async -> [String] { await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier) }
    func authorize() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    func remove(_ ids: [String]) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids) }
    func add(_ notification: CareNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = L10n.text("Bé Khỏe")
        content.body = L10n.text("Có lịch chăm sóc cần xem")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notification.date), repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
    }
}

final class LocalCareReminderService: CareReminderService {
    private var active = true
    private let prefix: String
    private let center: any CareNotificationCenter
    private var work: Task<String?, Never>?
    init(scope: String = "device", center: (any CareNotificationCenter)? = nil) {
        prefix = "babycare.\(scope)."
        self.center = center ?? SystemCareNotificationCenter()
    }
    func invalidate() async {
        active = false
        let ids = await center.pendingIDs()
        center.remove(ids.filter { $0.hasPrefix(prefix) })
    }

    func desired(in database: CareDatabase, now: Date = Date()) -> [CareNotification] {
        var result: [CareNotification] = []
        for baby in database.babies {
            let scope = prefix + baby.profile.id.uuidString + "."
            for item in baby.medicationReminders where item.enabled && item.nextDate > now {
                result.append(CareNotification(id: scope + "medication." + item.id.uuidString, date: item.nextDate))
            }
            for visit in baby.activities where visit.kind == .doctor {
                if let appointment = visit.followUpDate, DoctorFollowUp.reminderDate(for: appointment) > now {
                    result.append(CareNotification(id: scope + "followup." + visit.id.uuidString, date: DoctorFollowUp.reminderDate(for: appointment)))
                }
            }
            for item in baby.vaccinations where item.reminderEnabled {
                if let date = item.reminderDate, let next = item.nextDoseDate, date > now && date < next {
                    result.append(CareNotification(id: scope + "vaccination." + item.id.uuidString, date: date))
                }
            }
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    func reconcile(previous: CareDatabase, current: CareDatabase) async -> String? {
        // A load can finish while another action starts. Serialize effects so an
        // older permission prompt/add cannot overwrite a more recent schedule.
        let predecessor = work
        let task = Task { @MainActor [weak self] in
            _ = await predecessor?.value
            guard let self else { return nil as String? }
            return await self.performReconciliation(current: current)
        }
        work = task
        return await task.value
    }

    private func performReconciliation(current: CareDatabase) async -> String? {
        guard active else { return nil }
        let desired = desired(in: current)
        let wanted = Set(desired.map(\.id))
        let existing = await center.pendingIDs()
        guard active else { return nil }
        // This database is the active account/family. Remove stale app-owned
        // requests, including legacy random prefixes, but preserve other requests.
        center.remove(existing.filter { $0.hasPrefix("babycare.") && !wanted.contains($0) })
        guard !desired.isEmpty else { return nil }
        do {
            guard try await center.authorize() else {
                center.remove(existing.filter { $0.hasPrefix(prefix) })
                return L10n.text("Lịch đã lưu, chưa có quyền gửi thông báo")
            }
            for notification in desired {
                guard active else { return nil }
                // A stable identifier replaces an existing request after edits/relaunch.
                try await center.add(notification)
                if !active { center.remove([notification.id]); return nil }
            }
            return nil
        } catch { return L10n.text("Lịch đã lưu, chưa thể gửi thông báo") }
    }
}
