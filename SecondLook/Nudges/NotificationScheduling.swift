import Foundation

/// When a nudge should fire.
enum NudgeTrigger: Equatable {
    /// A wall-clock slot every week (e.g. Sunday 18:00), repeating.
    case weekly(weekday: Int, hour: Int, minute: Int)
    /// A one-shot delay from now (clamped to ≥ 60 s by the system).
    case after(seconds: TimeInterval)
}

/// One local notification SecondLook wants to schedule. `id` is stable so
/// re-scheduling replaces rather than stacks.
struct NudgeRequest: Equatable {
    var id: String
    var title: String
    var body: String
    var trigger: NudgeTrigger
    /// Deep-link target opened when the notification is tapped (`secondlook://…`).
    var deepLink: String?
}

enum NudgeAuthorization: Equatable {
    case notDetermined
    case provisional   // quiet delivery, no prompt shown
    case authorized
    case denied

    /// Can we deliver anything at all?
    var canDeliver: Bool { self == .provisional || self == .authorized }
}

/// The seam between SecondLook and `UNUserNotificationCenter`, so the nudge
/// logic is testable without the real notification system.
protocol NotificationScheduling: Sendable {
    func authorization() async -> NudgeAuthorization
    /// Ask for provisional (quiet) authorization. No-op if already decided.
    /// Returns whether we can now deliver.
    func requestProvisional() async -> Bool
    func pendingIDs() async -> Set<String>
    func schedule(_ request: NudgeRequest) async
    func cancel(ids: [String]) async
    func cancelAll() async
}

extension NotificationScheduling {
    func cancel(id: String) async { await cancel(ids: [id]) }
}
