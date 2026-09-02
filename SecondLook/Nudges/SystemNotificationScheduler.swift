import Foundation
import UserNotifications

/// `NotificationScheduling` backed by the real `UNUserNotificationCenter`.
struct SystemNotificationScheduler: NotificationScheduling {

    private var center: UNUserNotificationCenter { .current() }

    func authorization() async -> NudgeAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral: return .authorized
        case .provisional:            return .provisional
        case .denied:                 return .denied
        case .notDetermined:          return .notDetermined
        @unknown default:             return .notDetermined
        }
    }

    func requestProvisional() async -> Bool {
        let current = await authorization()
        guard current == .notDetermined else { return current.canDeliver }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])) ?? false
        return granted
    }

    func pendingIDs() async -> Set<String> {
        let pending = await center.pendingNotificationRequests()
        return Set(pending.map(\.identifier))
    }

    func schedule(_ request: NudgeRequest) async {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        if let link = request.deepLink {
            content.userInfo = ["deepLink": link]
        }

        let trigger: UNNotificationTrigger
        switch request.trigger {
        case let .weekly(weekday, hour, minute):
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = hour
            comps.minute = minute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        case let .after(seconds):
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        }

        // Replace any existing request with this id.
        center.removePendingNotificationRequests(withIdentifiers: [request.id])
        let req = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        try? await center.add(req)
    }

    func cancel(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }
}
