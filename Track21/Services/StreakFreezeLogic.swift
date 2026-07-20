//
//  StreakFreezeLogic.swift
//  Track21
//
//  Created by Track21 Team on 12/7/2026.
//
//  Pure decision logic for the streak-freeze feature, kept separate from
//  StreakFreezeService's UserDefaults/singleton plumbing so it's fully unit
//  testable with fabricated habits and wallets — no shared app state.
//

import Foundation

struct FreezeWallet: Codable, Equatable {
    var freezesAvailable: Int
    var refillDate: Date
}

enum StreakFreezeLogic {
    static let freeMonthlyAllowance = 2

    /// The 1st of the month following `date`, at midnight.
    static func nextRefillDate(from date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.month = (components.month ?? 1) + 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    /// Tops the wallet back up to the free monthly allowance once its
    /// refill date has passed. No-ops otherwise (including for premium
    /// wallets, which never run out in the first place).
    static func refilled(_ wallet: FreezeWallet, referenceDate: Date, calendar: Calendar = .current) -> FreezeWallet {
        guard referenceDate >= wallet.refillDate else { return wallet }
        return FreezeWallet(
            freezesAvailable: freeMonthlyAllowance,
            refillDate: nextRefillDate(from: referenceDate, calendar: calendar)
        )
    }

    /// If `habit` missed exactly yesterday while mid-streak, returns that
    /// date as eligible for protection. Only ever looks at yesterday — a
    /// habit missed two days in a row without the app being opened only
    /// gets the more recent day protected, matching how Duolingo's streak
    /// freeze behaves.
    static func dateNeedingProtection(for habit: Habit, today: Date, calendar: Calendar = .current) -> Date? {
        let todayStart = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let dayBeforeYesterday = calendar.date(byAdding: .day, value: -1, to: yesterday) else {
            return nil
        }
        guard habit.dateStatus(for: yesterday) == .missed else { return nil }
        guard habit.currentStreak(asOf: dayBeforeYesterday) > 0 else { return nil }
        return yesterday
    }

    /// Pure decision pass: given a set of habits and the current wallet,
    /// decides which habits get a freeze applied and what the wallet looks
    /// like afterward. Doesn't mutate anything — the caller (StreakFreezeService)
    /// applies the results and persists.
    ///
    /// One freeze protects the whole day, not one habit — every eligible
    /// habit that needs protection shares a single freeze from the wallet.
    /// Charging per habit would let one rough day (multiple habits missed
    /// at once) burn through the entire monthly allowance in one shot,
    /// which isn't what "a streak freeze" means to most users.
    static func protect(
        habits: [Habit],
        wallet: FreezeWallet,
        isPremium: Bool,
        today: Date,
        calendar: Calendar = .current
    ) -> (protected: [(habit: Habit, date: Date)], wallet: FreezeWallet) {
        var wallet = refilled(wallet, referenceDate: today, calendar: calendar)

        let eligible = habits.compactMap { habit -> (habit: Habit, date: Date)? in
            guard let date = dateNeedingProtection(for: habit, today: today, calendar: calendar) else { return nil }
            return (habit, date)
        }

        guard !eligible.isEmpty else { return ([], wallet) }
        guard isPremium || wallet.freezesAvailable > 0 else { return ([], wallet) }

        if !isPremium {
            wallet.freezesAvailable -= 1
        }

        return (eligible, wallet)
    }
}
