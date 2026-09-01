import Foundation
import Observation

/// Tracks how many Deep AI Checks have been used this calendar month.
///
/// - Free: `SubscriptionPlan.free.deepCheckAllowance` (2) per month
/// - Plus: `SubscriptionPlan.plus.deepCheckAllowance` (20) per month
///
/// The ledger is stored in the keychain, so deleting and reinstalling the app
/// does **not** reset the count (a plain `UserDefaults` value would). A full
/// device erase or a manual keychain wipe still resets it — genuinely
/// tamper-proof limits need a server identity, which SecondLook deliberately
/// does not have. See the completion notes.
@Observable
final class DeepCheckQuota {
    private struct Ledger: Codable {
        var month: String       // "yyyy-MM"
        var used: Int
    }

    private let keychainKey: String
    private let calendar: Calendar
    private let now: () -> Date
    private var ledger: Ledger

    private(set) var used: Int = 0

    init(calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init,
         keychainKey: String = "deepcheck.ledger.v1") {
        self.keychainKey = keychainKey
        self.calendar = calendar
        self.now = now
        self.ledger = Self.load(key: keychainKey) ?? Ledger(month: Self.monthKey(now(), calendar), used: 0)
        rolloverIfNeeded()
    }

    /// Deep checks remaining this month for the given plan.
    func remaining(plan: SubscriptionPlan) -> Int {
        rolloverIfNeeded()
        return max(0, plan.deepCheckAllowance - ledger.used)
    }

    func canRun(plan: SubscriptionPlan) -> Bool {
        remaining(plan: plan) > 0
    }

    /// Records one used deep check. Call only after a successful run.
    func recordRun() {
        rolloverIfNeeded()
        ledger.used += 1
        used = ledger.used
        persist()
    }

    /// Human-readable "1 of 2 this month" style status.
    func statusLine(plan: SubscriptionPlan) -> String {
        let left = remaining(plan: plan)
        let total = plan.deepCheckAllowance
        if left == 0 {
            return "You've used all \(total) Deep AI Checks this month."
        }
        return "\(left) of \(total) Deep AI Checks left this month."
    }

    // MARK: - Month rollover

    private func rolloverIfNeeded() {
        let currentMonth = Self.monthKey(now(), calendar)
        if ledger.month != currentMonth {
            ledger = Ledger(month: currentMonth, used: 0)
            used = 0
            persist()
        } else {
            used = ledger.used
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(ledger),
              let json = String(data: data, encoding: .utf8) else { return }
        KeychainStore.set(json, for: keychainKey)
    }

    private static func load(key: String) -> Ledger? {
        guard let json = KeychainStore.string(for: key),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Ledger.self, from: data)
    }

    private static func monthKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    #if DEBUG
    /// Test hook — reset the keychain ledger and re-read.
    func wipeForTesting() {
        KeychainStore.remove(keychainKey)
        ledger = Ledger(month: Self.monthKey(now(), calendar), used: 0)
        used = 0
    }
    #endif
}
