import Foundation
import Observation
import UserNotifications

/// Handles a tapped notification: pulls the `deepLink` out of its payload and
/// publishes it for `RootView` to route on. Also lets the quiet-thread nudge
/// show while the app is in the foreground.
@MainActor
@Observable
final class NudgeRouter: NSObject, UNUserNotificationCenterDelegate {

    /// Set when a notification is tapped; `RootView` observes this and clears it.
    var pendingDeepLink: URL?

    /// Call once at launch.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = (response.notification.request.content.userInfo["deepLink"] as? String)
            .flatMap(URL.init(string:))
        Task { @MainActor in
            if let link { self.pendingDeepLink = link }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
