//
//  PremiumService.swift
//  Track21
//
//  Owns Track21 Pro's entitlement state via StoreKit 2. Three products in one
//  subscription group (see Config/Track21.storekit for local testing):
//  monthly, annual (7-day trial), and a lifetime non-consumable — any one of
//  them grants the same `isPremium` flag everywhere else in the app reads.
//

import Foundation
import StoreKit

@Observable
final class PremiumService {
    static let shared = PremiumService()

    static let monthlyID = "com.yourbaecodes.trackHabit.pro.monthly"
    static let annualID = "com.yourbaecodes.trackHabit.pro.annual"
    static let lifetimeID = "com.yourbaecodes.trackHabit.pro.lifetime"
    static let allProductIDs = [monthlyID, annualID, lifetimeID]

    private(set) var products: [Product] = []
    private(set) var hasActiveEntitlement = false
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String?

    #if DEBUG
    private let debugOverrideKey = "Track21DebugIsPremium"
    /// Manual override for local testing only — compiled out of release
    /// builds, so it can never affect a real user's entitlement.
    var debugOverride: Bool {
        didSet { UserDefaults.standard.set(debugOverride, forKey: debugOverrideKey) }
    }
    #endif

    /// Single source of truth the rest of the app reads — real StoreKit
    /// entitlement, or (DEBUG only) the manual override from the debug menu.
    var isPremium: Bool {
        #if DEBUG
        if debugOverride { return true }
        #endif
        return hasActiveEntitlement
    }

    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        #if DEBUG
        debugOverride = UserDefaults.standard.bool(forKey: debugOverrideKey)
        #endif
        transactionListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { lhs, rhs in
                Self.allProductIDs.firstIndex(of: lhs.id) ?? 0 < Self.allProductIDs.firstIndex(of: rhs.id) ?? 0
            }
        } catch {
            NSLog("PremiumService: failed to load products: %@", String(describing: error))
            purchaseError = "Couldn't load Track21 Pro pricing. Check your connection and try again."
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        purchaseError = nil
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                purchaseError = "Couldn't verify that purchase. Please try again."
                return false
            }
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled:
            return false
        case .pending:
            purchaseError = "Purchase pending — ask a family member to approve it, or check back shortly."
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.allProductIDs.contains(transaction.productID) {
                active = true
            }
        }
        hasActiveEntitlement = active
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
