import Foundation
import Observation

/// Coordinates SecondLook's two local notifications:
///   • a gentle **weekly** "practice a round / a pattern to know" nudge, keyed
///     off the Spot-the-scam streak, and
///   • a one-off **quiet-thread** nudge a few days after a flagged reply when
///     the conversation has gone silent.
///
/// Everything is local — no push server, no account. Uses *provisional*
/// authorization so nothing ever interrupts the user with a permission prompt;
/// quiet notifications land in Notification Center and the user promotes or
/// silences them from there, or from the About tab.
@MainActor
@Observable
final class NudgeManager {

    static let enabledKey = "secondlook.nudges.enabled"
    static let weeklyID = "practice.weekly"
    private static let quietPrefix = "thread.quiet."
    private static let quietAfter: TimeInterval = 3 * 86_400
    private static let quietMaxAge: TimeInterval = 21 * 86_400

    private let scheduler: NotificationScheduling
    private let defaults: UserDefaults

    private(set) var authorization: NudgeAuthorization = .notDetermined

    var enabled: Bool {
        didSet {
            guard oldValue != enabled else { return }
            defaults.set(enabled, forKey: Self.enabledKey)
        }
    }

    init(scheduler: NotificationScheduling = SystemNotificationScheduler(),
         defaults: UserDefaults = .standard) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.enabled = (defaults.object(forKey: Self.enabledKey) as? Bool) ?? true
    }

    // MARK: Lifecycle

    /// Called once on launch and again when the app returns to the foreground.
    func bootstrap(progress: PracticeProgress, threads: [ConversationThread]) async {
        if enabled {
            _ = await scheduler.requestProvisional()
        }
        authorization = await scheduler.authorization()
        await refreshWeeklyPractice(progress: progress)
        await syncQuietThreads(threads)
    }

    /// The user flipped the About-tab toggle.
    func setEnabled(_ on: Bool, progress: PracticeProgress, threads: [ConversationThread]) async {
        enabled = on
        if on {
            _ = await scheduler.requestProvisional()
            authorization = await scheduler.authorization()
        }
        await refreshWeeklyPractice(progress: progress)
        await syncQuietThreads(threads)
    }

    /// A natural moment to ask for (quiet) permission: the user just finished a
    /// practice round, so they're engaged.
    func practiceRoundCompleted(progress: PracticeProgress) async {
        if enabled { _ = await scheduler.requestProvisional() }
        authorization = await scheduler.authorization()
        await refreshWeeklyPractice(progress: progress)
    }

    // MARK: Weekly practice nudge

    func refreshWeeklyPractice(progress: PracticeProgress, now: Date = Date()) async {
        await refreshAuthorizationIfUnknown()
        guard enabled, authorization.canDeliver else {
            await scheduler.cancel(id: Self.weeklyID)
            return
        }
        let copy = NudgeContent.weeklyPractice(progress: progress, weekIndex: Self.weekIndex(now), now: now)
        await scheduler.schedule(NudgeRequest(
            id: Self.weeklyID,
            title: copy.title,
            body: copy.body,
            trigger: .weekly(weekday: 1, hour: 18, minute: 0),   // Sunday evening
            deepLink: "secondlook://learn"
        ))
    }

    // MARK: Quiet-thread nudge

    func syncQuietThreads(_ threads: [ConversationThread], now: Date = Date()) async {
        await refreshAuthorizationIfUnknown()
        let pending = await scheduler.pendingIDs()

        guard enabled, authorization.canDeliver else {
            let ours = pending.filter { $0.hasPrefix(Self.quietPrefix) }
            if !ours.isEmpty { await scheduler.cancel(ids: Array(ours)) }
            return
        }

        let qualifying = threads.filter {
            $0.currentOverall != .clear
            && !$0.messages.isEmpty
            && now.timeIntervalSince($0.updatedAt) < Self.quietMaxAge
        }
        let qualifyingByID = Dictionary(uniqueKeysWithValues: qualifying.map { ($0.id, $0) })

        // Arm (or re-arm) a nudge for each qualifying thread whose latest
        // activity we haven't already scheduled against.
        for thread in qualifying {
            let key = activityKey(thread.id)
            let armedFor = defaults.double(forKey: key)
            let activity = thread.updatedAt.timeIntervalSinceReferenceDate
            guard activity > armedFor + 1 else { continue }

            let elapsed = now.timeIntervalSince(thread.updatedAt)
            let delay = max(60, Self.quietAfter - elapsed)
            let copy = NudgeContent.quietThread(label: thread.label, level: thread.currentOverall)
            await scheduler.schedule(NudgeRequest(
                id: Self.quietPrefix + thread.id.uuidString,
                title: copy.title,
                body: copy.body,
                trigger: .after(seconds: delay),
                deepLink: "secondlook://thread/\(thread.id.uuidString)"
            ))
            defaults.set(activity, forKey: key)
        }

        // Cancel nudges for threads that no longer qualify (now clear, deleted,
        // or too old to matter).
        let stale = pending.filter { id in
            guard id.hasPrefix(Self.quietPrefix) else { return false }
            let uuid = UUID(uuidString: String(id.dropFirst(Self.quietPrefix.count)))
            return uuid == nil || qualifyingByID[uuid!] == nil
        }
        if !stale.isEmpty {
            await scheduler.cancel(ids: Array(stale))
            for id in stale {
                if let uuid = UUID(uuidString: String(id.dropFirst(Self.quietPrefix.count))) {
                    defaults.removeObject(forKey: activityKey(uuid))
                }
            }
        }
    }

    // MARK: Helpers

    private func activityKey(_ id: UUID) -> String { "nudge.thread.\(id.uuidString).activity" }

    /// The system authorization state can change outside the app (Settings, or
    /// the user acting on a provisional notification). Re-read it lazily so a
    /// sync triggered before `bootstrap` finished isn't working off the default.
    private func refreshAuthorizationIfUnknown() async {
        if authorization == .notDetermined {
            authorization = await scheduler.authorization()
        }
    }

    /// A stable integer that advances once a week — drives copy rotation.
    static func weekIndex(_ date: Date = Date()) -> Int {
        Int(date.timeIntervalSince1970 / (7 * 86_400))
    }
}
