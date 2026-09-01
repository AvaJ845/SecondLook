import Foundation
import StoreKit
import Observation

/// StoreKit 2 wrapper for SecondLook Plus. Owns product loading, purchase, the
/// transaction-updates listener, and restore. Resolves the current plan and
/// pushes it into `Entitlements` — nothing else in the app touches StoreKit.
@Observable
@MainActor
final class SubscriptionManager {

    /// Product identifiers — must match App Store Connect and `SecondLook.storekit`.
    enum ProductID {
        static let monthly = "com.avaresearch.secondlook.plus.monthly"
        static let yearly = "com.avaresearch.secondlook.plus.yearly"
        static let all: Set<String> = [monthly, yearly]
    }

    enum PurchaseOutcome: Equatable {
        case success
        case pending          // Ask to Buy / SCA — resolves later via updates
        case userCancelled
        case failed(String)
    }

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    private(set) var monthly: Product?
    private(set) var yearly: Product?
    private(set) var loadState: LoadState = .idle
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isEligibleForIntroOffer = true

    private let entitlements: Entitlements
    private var updatesTask: Task<Void, Never>?

    init(entitlements: Entitlements) {
        self.entitlements = entitlements
    }

    /// Call once at launch. Starts the transaction listener, loads products, and
    /// resolves the current entitlement.
    func start() async {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(transactionResult: update)
            }
        }
        await loadProducts()
        await refreshEntitlement()
        await refreshIntroEligibility()
        entitlements.markResolved()
    }

    // MARK: - Products

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: ProductID.all)
            for product in products {
                switch product.id {
                case ProductID.monthly: monthly = product
                case ProductID.yearly: yearly = product
                default: break
                }
            }
            loadState = (monthly != nil || yearly != nil) ? .loaded : .failed("No products returned")
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Purchase / restore

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
                await refreshIntroEligibility()
                return .success
            case .pending:
                return .pending
            case .userCancelled:
                return .userCancelled
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> PurchaseOutcome {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            return entitlements.isPlus ? .success : .failed("No active SecondLook Plus subscription found for this Apple ID.")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Entitlement resolution

    func refreshEntitlement() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productType == .autoRenewable,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIDs = owned
        entitlements.update(plan: owned.isEmpty ? .free : .plus)
    }

    private func refreshIntroEligibility() async {
        // Eligible only if the user has no prior transaction in the group.
        guard let product = yearly ?? monthly,
              let subscription = product.subscription else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(transactionResult) else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }

    // MARK: - Presentation helpers (prices ALWAYS from StoreKit, never hard-coded)

    var yearlyPriceText: String? { yearly?.displayPrice }
    var monthlyPriceText: String? { monthly?.displayPrice }

    /// "About $4.17/month" derived from the yearly `Product.price`, localized.
    var yearlyPerMonthText: String? {
        guard let yearly else { return nil }
        let perMonth = yearly.price / Decimal(12)
        return perMonth.formatted(yearly.priceFormatStyle) + "/mo"
    }

    /// e.g. "7-day free trial" — only when the store actually configures a free
    /// trial and the user is eligible. Never assumed.
    func introOfferText(for product: Product?) -> String? {
        guard isEligibleForIntroOffer,
              let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        let days: Int
        switch p.unit {
        case .day: days = p.value
        case .week: days = p.value * 7
        case .month: days = p.value * 30
        case .year: days = p.value * 365
        @unknown default: days = p.value
        }
        return "\(days)-day free trial"
    }
}
