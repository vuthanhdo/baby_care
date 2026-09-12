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

final class LocalCareReminderService: CareReminderService {
    private var active = true
    private let prefix = "babycare.\(UUID().uuidString)."
    private var identifiers: Set<String> = []
    func invalidate() async {
        active = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(identifiers))
    }
    func reconcile(previous: CareDatabase, current: CareDatabase) async -> String? {
        guard active else { return nil }
        let old = previous.babies.flatMap(\.medicationReminders)
        let new = current.babies.flatMap(\.medicationReminders)
        let changed = new.filter { item in old.first { $0.id == item.id } != item }
        let removed = old.filter { item in !new.contains { $0.id == item.id } }
        guard !changed.isEmpty || !removed.isEmpty else { return nil }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (changed + removed).map { prefix + $0.id.uuidString })
        let pending = changed.filter { $0.enabled && $0.nextDate > Date() }
        guard !pending.isEmpty else { return nil }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                return L10n.text("Lịch đã lưu, chưa có quyền gửi thông báo")
            }
            for reminder in pending {
                guard active else { return nil }
                let content = UNMutableNotificationContent()
                content.title = L10n.text("Bé Khỏe")
                content.body = L10n.text("Có lịch chăm sóc cần xem")
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.nextDate), repeats: false)
                let id = prefix + reminder.id.uuidString
                identifiers.insert(id)
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                if !active { center.removePendingNotificationRequests(withIdentifiers: [id]); return nil }
            }
            return nil
        } catch { return L10n.text("Lịch đã lưu, chưa thể gửi thông báo") }
    }
}
