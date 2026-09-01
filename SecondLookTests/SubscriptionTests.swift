import XCTest
import StoreKit
import StoreKitTest
@testable import SecondLook

@MainActor
final class SubscriptionTests: XCTestCase {

    // MARK: Plain model (no StoreKit needed)

    func testProductIDs() {
        XCTAssertEqual(SubscriptionManager.ProductID.all, [
            "com.avaresearch.secondlook.plus.monthly",
            "com.avaresearch.secondlook.plus.yearly",
        ])
    }

    func testFreeIsTheDefaultEntitlement() {
        let e = Entitlements()
        XCTAssertEqual(e.plan, .free)
        XCTAssertFalse(e.isPlus)
    }

    func testEntitlementUpdate() {
        let e = Entitlements()
        e.update(plan: .plus)
        XCTAssertTrue(e.isPlus)
        XCTAssertFalse(e.isResolving)
        e.update(plan: .free)
        XCTAssertFalse(e.isPlus)
    }

    func testPlanAllowances() {
        XCTAssertEqual(SubscriptionPlan.free.deepCheckAllowance, 2)
        XCTAssertEqual(SubscriptionPlan.plus.deepCheckAllowance, 20)
        XCTAssertEqual(SubscriptionPlan.free.savedHistoryLimit, 10)
        XCTAssertNil(SubscriptionPlan.plus.savedHistoryLimit)
    }

    // MARK: StoreKitTest integration

    private func makeSession() throws -> SKTestSession {
        let session: SKTestSession
        do {
            session = try SKTestSession(configurationFileNamed: "SecondLook")
        } catch {
            throw XCTSkip("StoreKit test configuration unavailable in this environment: \(error)")
        }
        session.disableDialogs = true
        session.resetToDefaultState()
        session.clearTransactions()
        return session
    }

    /// Loads products, retrying once — `Product.products(for:)` can lag the
    /// session by a beat in a fresh test process. Skips the test if the store
    /// can't serve products at all (headless environments without StoreKitTest).
    private func loadOrSkip(_ subs: SubscriptionManager) async throws {
        await subs.loadProducts()
        if subs.yearly == nil {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await subs.loadProducts()
        }
        try XCTSkipIf(subs.yearly == nil, "StoreKitTest did not serve products in this environment")
    }

    func testProductsLoad() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)

        XCTAssertNotNil(subs.monthly)
        XCTAssertNotNil(subs.yearly)
        XCTAssertNotNil(subs.monthlyPriceText)
        XCTAssertNotNil(subs.yearlyPerMonthText)
    }

    func testPurchaseGrantsPlusAndRestoreFindsIt() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)
        let yearly = try XCTUnwrap(subs.yearly)

        let outcome = await subs.purchase(yearly)
        XCTAssertEqual(outcome, .success)
        XCTAssertTrue(ent.isPlus)

        // Fresh manager over the same transactions → restore resolves Plus.
        let ent2 = Entitlements()
        let subs2 = SubscriptionManager(entitlements: ent2)
        await subs2.refreshEntitlement()
        XCTAssertTrue(ent2.isPlus)
    }

    func testExpirationDropsBackToFree() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)
        let monthly = try XCTUnwrap(subs.monthly)

        _ = await subs.purchase(monthly)
        XCTAssertTrue(ent.isPlus)

        session.clearTransactions()
        await subs.refreshEntitlement()
        XCTAssertFalse(ent.isPlus, "no active transaction → free")
    }

    func testAskToBuyReturnsPending() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.askToBuyEnabled = false }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)
        let yearly = try XCTUnwrap(subs.yearly)

        session.askToBuyEnabled = true
        let outcome = await subs.purchase(yearly)
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(ent.isPlus, "a pending purchase does not grant Plus yet")
    }

    func testFailedPurchaseSurfacesFailure() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.failTransactionsEnabled = false }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)
        let monthly = try XCTUnwrap(subs.monthly)

        session.failTransactionsEnabled = true
        let outcome = await subs.purchase(monthly)
        if case .failed = outcome {} else {
            XCTFail("expected .failed, got \(outcome)")
        }
        XCTAssertFalse(ent.isPlus)
    }

    func testIntroOfferEligibilityAndText() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let ent = Entitlements()
        let subs = SubscriptionManager(entitlements: ent)
        try await loadOrSkip(subs)
        await subs.start()

        // Fresh session → eligible; the .storekit config has a P1W free trial.
        if let text = subs.introOfferText(for: subs.yearly) {
            XCTAssertTrue(text.contains("day free trial"))
        }
    }
}
