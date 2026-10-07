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
    /// True only for a live monthly/annual subscription — a lifetime purchase
    /// has nothing to manage, so Profile hides "Manage Subscription" for it.
    private(set) var hasActiveSubscription = false
    /// Subscription product IDs whose introductory offer (the annual free
    /// trial) this Apple Account can still redeem. The paywall only promises
    /// a trial for IDs in here.
    private(set) var introOfferEligibleIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String?

    #if DEBUG
    private let debugOverrideKey = "Track21DebugIsPremium"
    private let debugForceFreeKey = "Track21DebugForceFree"
    /// Manual override for local testing only — compiled out of release
    /// builds, so it can never affect a real user's entitlement.
    var debugOverride: Bool {
        didSet { UserDefaults.standard.set(debugOverride, forKey: debugOverrideKey) }
    }
    /// Force free user state, ignoring any real entitlements — for testing
    /// the free tier experience even after a sandbox purchase.
    var debugForceFree: Bool {
        didSet { UserDefaults.standard.set(debugForceFree, forKey: debugForceFreeKey) }
    }
    #endif

    /// Single source of truth the rest of the app reads — real StoreKit
    /// entitlement, or (DEBUG only) the manual override from the debug menu.
    var isPremium: Bool {
        #if DEBUG
        if debugForceFree { return false }
        if debugOverride { return true }
        #endif
        return hasActiveEntitlement
    }

    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        #if DEBUG
        debugOverride = UserDefaults.standard.bool(forKey: debugOverrideKey)
        debugForceFree = UserDefaults.standard.bool(forKey: debugForceFreeKey)
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

    func loadProducts(force: Bool = false) async {
        if !force && !products.isEmpty { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { lhs, rhs in
                Self.allProductIDs.firstIndex(of: lhs.id) ?? 0 < Self.allProductIDs.firstIndex(of: rhs.id) ?? 0
            }
            await refreshIntroOfferEligibility()
            if products.isEmpty {
                purchaseError = "No Track21 Pro products found. For local testing, run from Xcode with Track21.storekit selected in the scheme. For a device Sandbox test, create matching IAP products in App Store Connect."
                NSLog("PremiumService: Product.products returned empty for %@", Self.allProductIDs.joined(separator: ", "))
            } else {
                purchaseError = nil
            }
        } catch {
            NSLog("PremiumService: failed to load products: %@", String(describing: error))
            purchaseError = "Couldn't load Track21 Pro pricing. Check your connection and try again."
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        purchaseError = nil
        do {
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
                purchaseError = "Purchase didn't complete. Please try again."
                return false
            }
        } catch {
            NSLog("PremiumService: purchase failed: %@", String(describing: error))
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }

    func restorePurchases() async throws {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasActiveEntitlement {
                purchaseError = "No previous Track21 Pro purchase found to restore."
            } else {
                purchaseError = nil
            }
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
            throw error
        }
    }

    func refreshEntitlements() async {
        var active = false
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.allProductIDs.contains(transaction.productID) {
                active = true
                if transaction.productType == .autoRenewable {
                    subscribed = true
                }
            }
        }
        hasActiveEntitlement = active
        hasActiveSubscription = subscribed
        // A purchase or expiry can change trial eligibility, so re-check.
        await refreshIntroOfferEligibility()
    }

    private func refreshIntroOfferEligibility() async {
        var eligible: Set<String> = []
        for product in products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer != nil else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligible.insert(product.id)
            }
        }
        introOfferEligibleIDs = eligible
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
