import Foundation
import UserNotifications

/// One serialized writer. Repeated refreshes are coalesced; stale writes never win.
@MainActor
final class JarvisNotifications {
    static let shared = JarvisNotifications()
    private var latest: JarvisMemory?
    private var draining = false
    private var generation = 0
    private let preferenceKey = "jarvis-reminders-on"
    var enabled: Bool { UserDefaults.standard.bool(forKey: preferenceKey) }

    func enable(memory: JarvisMemory) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw ReminderError.denied }
        UserDefaults.standard.set(true, forKey: preferenceKey)
        try await refresh(memory: memory)
    }
    func refresh(memory: JarvisMemory) async throws {
        guard enabled else { return }
        latest = memory
        guard !draining else { return }
        draining = true
        defer { draining = false }
        let center = UNUserNotificationCenter.current()
        while let snapshot = latest {
            latest = nil
            let stamp = generation
            let settings = await center.notificationSettings()
            guard enabled, stamp == generation else { continue }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { throw ReminderError.denied }
            let plan = ReminderPlanner.make(memory: snapshot, now: Date())
            let old = await center.pendingNotificationRequests()
            guard enabled, stamp == generation else { continue }
            let desired = Set(plan.map(\.id))
            let stale = old.filter { $0.identifier.hasPrefix("jarvis-") && !desired.contains($0.identifier) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for item in plan {
                guard enabled, stamp == generation else { break }
                let content = UNMutableNotificationContent()
                content.title = "JARVIS · \(item.title)"; content.body = item.body
                content.sound = .default
                content.userInfo = ["jarvisDay": item.day, "jarvisActivity": item.taskID]
                var components = snapshot.settings.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
                components.timeZone = snapshot.settings.calendar.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await center.add(.init(identifier: item.id, content: content, trigger: trigger))
                // Disable may run while center.add is suspended.
                if !enabled || stamp != generation { center.removePendingNotificationRequests(withIdentifiers: [item.id]); break }
            }
        }
    }
    func disable() async {
        UserDefaults.standard.set(false, forKey: preferenceKey)
        generation += 1; latest = nil
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("jarvis-") }.map(\.identifier))
        center.removeAllDeliveredNotifications()
    }
    enum ReminderError: LocalizedError {
        case denied
        var errorDescription: String? { "Bildirim izni kapalı. iPhone Ayarlar > Bildirimler > JARVIS üzerinden açabilirsin." }
    }
}

struct NotificationRoute: Codable {
    var day: String
    var taskID: String
    private static let key = "jarvis-pending-route"
    static func save(day: String, taskID: String) {
        if let data = try? JSONEncoder().encode(Self(day: day, taskID: taskID)) { UserDefaults.standard.set(data, forKey: key) }
    }
    static func consume() -> Self? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
