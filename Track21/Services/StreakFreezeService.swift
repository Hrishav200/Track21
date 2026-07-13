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
    /// No real StoreKit/IAP wired up yet — always free tier for now.
    var isPremium: Bool = false

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
}
