import Foundation
import Observation

/// What a plan unlocks. The rest of the app reads `Entitlements`, never StoreKit
/// directly, and never these raw numbers except through `Entitlements` helpers.
enum SubscriptionPlan: String, Codable, Sendable {
    case free
    case plus

    var displayName: String {
        switch self {
        case .free: return "SecondLook"
        case .plus: return "SecondLook Plus"
        }
    }

    /// Deep AI Checks per calendar month.
    var deepCheckAllowance: Int {
        switch self {
        case .free: return 2
        case .plus: return 20
        }
    }

    /// How many saved checks the History tab shows. Free keeps a recent window;
    /// Plus keeps everything. Basic on-device checking is never limited.
    var savedHistoryLimit: Int? {
        switch self {
        case .free: return 10
        case .plus: return nil
        }
    }
}

/// The single source of truth for "what can this user do." `SubscriptionManager`
/// pushes updates in (from the main actor); features only ever read.
@Observable
final class Entitlements {
    private(set) var plan: SubscriptionPlan = .free

    /// True while StoreKit is still resolving on first launch, so the UI can
    /// avoid flashing a paywall before we know the real state.
    private(set) var isResolving: Bool = true

    var isPlus: Bool { plan == .plus }

    func update(plan: SubscriptionPlan) {
        self.plan = plan
        self.isResolving = false
    }

    func markResolved() { isResolving = false }
}
