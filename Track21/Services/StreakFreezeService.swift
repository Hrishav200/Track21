//
//  StreakFreezeService.swift
//  Track21
//
//  Created by Track21 Team on 12/7/2026.
//

import Foundation

/// Owns the freeze wallet (persisted to UserDefaults, local-only — same
/// caveat as reminders/notifications, no Supabase column for this yet) and
/// applies StreakFreezeLogic's decisions to real Habit instances.
@Observable
final class StreakFreezeService {
    static let shared = StreakFreezeService()

    private let walletKey = "Track21FreezeWallet"

    private(set) var wallet: FreezeWallet
    /// Backed by PremiumService (StoreKit entitlement, or the DEBUG-only
    /// override) — this is just a convenience passthrough so callers that
    /// already depend on StreakFreezeService don't need a second import.
    var isPremium: Bool { PremiumService.shared.isPremium }

    var freezesAvailable: Int { wallet.freezesAvailable }
    var refillDate: Date { wallet.refillDate }

    private init() {
        if let data = UserDefaults.standard.data(forKey: walletKey),
           let stored = try? JSONDecoder().decode(FreezeWallet.self, from: data) {
            wallet = stored
        } else {
            wallet = FreezeWallet(
                freezesAvailable: StreakFreezeLogic.freeMonthlyAllowance,
                refillDate: StreakFreezeLogic.nextRefillDate(from: Date())
            )
        }
    }

    /// Call once per app foreground. Auto-protects any habit that missed
    /// exactly yesterday while mid-streak, consuming a freeze per habit
    /// until the wallet runs out. Returns the habits that got protected so
    /// the caller can show a toast and persist the updated habits.
    @discardableResult
    func protectStreaks(for habits: [Habit], today: Date = Date()) -> [Habit] {
        let (protectedPairs, newWallet) = StreakFreezeLogic.protect(
            habits: habits,
            wallet: wallet,
            isPremium: isPremium,
            today: today
        )

        for (habit, date) in protectedPairs {
            habit.frozenDates.append(date)
            // Without this, the freeze never gets uploaded (SyncService only
            // pushes .pending habits) and the next sync pulls back the
            // server's stale copy, silently erasing the freeze it just applied.
            habit.syncStatus = .pending
            habit.updatedAt = Date()
        }

        if newWallet != wallet {
            wallet = newWallet
            persist()
        }

        return protectedPairs.map(\.habit)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(wallet) {
            UserDefaults.standard.set(data, forKey: walletKey)
        }
    }

    #if DEBUG
    /// Compiled out of release builds — only reachable from DebugMenuView.
    func debugAdjustFreezes(by delta: Int) {
        wallet.freezesAvailable = max(0, wallet.freezesAvailable + delta)
        persist()
    }

    func debugResetWallet() {
        wallet = FreezeWallet(
            freezesAvailable: StreakFreezeLogic.freeMonthlyAllowance,
            refillDate: StreakFreezeLogic.nextRefillDate(from: Date())
        )
        persist()
    }
    #endif
}
