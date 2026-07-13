//
//  StreakFreezeTests.swift
//  Track21Tests
//
//  Created by Track21 Team on 12/7/2026.
//
//  Tests StreakFreezeLogic's pure functions directly — no UserDefaults, no
//  StreakFreezeService singleton — so these are fully deterministic and
//  don't share state with other tests or the app's real freeze wallet.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct StreakFreezeTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    // MARK: - nextRefillDate / refilled

    @Test func nextRefillDateIsTheFirstOfNextMonth() {
        var components = DateComponents(year: 2026, month: 3, day: 15)
        let march15 = calendar.date(from: components)!

        let refill = StreakFreezeLogic.nextRefillDate(from: march15, calendar: calendar)
        components = calendar.dateComponents([.year, .month, .day], from: refill)

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 1)
    }

    @Test func nextRefillDateRollsOverIntoNextYear() {
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let refill = StreakFreezeLogic.nextRefillDate(from: december, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: refill)

        #expect(components.year == 2027)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @Test func refillLeavesWalletUntouchedBeforeRefillDate() {
        let refillDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let wallet = FreezeWallet(freezesAvailable: 0, refillDate: refillDate)
        let checkDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!

        let result = StreakFreezeLogic.refilled(wallet, referenceDate: checkDate, calendar: calendar)
        #expect(result == wallet)
    }

    @Test func refillTopsUpOncePastRefillDate() {
        let refillDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let wallet = FreezeWallet(freezesAvailable: 0, refillDate: refillDate)
        let checkDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 2))!

        let result = StreakFreezeLogic.refilled(wallet, referenceDate: checkDate, calendar: calendar)
        #expect(result.freezesAvailable == StreakFreezeLogic.freeMonthlyAllowance)
        #expect(result.refillDate > checkDate)
    }

    // MARK: - dateNeedingProtection

    @Test func missedYesterdayWithActiveStreakIsEligible() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(10))
        // Completed everything through 2 days ago; missed yesterday.
        for offset in 2...10 {
            habit.completedDates.append(daysAgo(offset))
        }

        let date = StreakFreezeLogic.dateNeedingProtection(for: habit, today: Date(), calendar: calendar)
        #expect(date != nil)
        #expect(date.map { calendar.isDate($0, inSameDayAs: daysAgo(1)) } == true)
    }

    @Test func completedYesterdayIsNotEligible() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(10))
        for offset in 1...10 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(StreakFreezeLogic.dateNeedingProtection(for: habit, today: Date(), calendar: calendar) == nil)
    }

    @Test func missedYesterdayWithNoPriorStreakIsNotEligible() {
        // Nothing completed at all — no streak to protect.
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(10))
        #expect(StreakFreezeLogic.dateNeedingProtection(for: habit, today: Date(), calendar: calendar) == nil)
    }

    @Test func alreadyFrozenYesterdayIsNotEligibleAgain() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(10))
        for offset in 2...10 {
            habit.completedDates.append(daysAgo(offset))
        }
        habit.frozenDates.append(daysAgo(1))

        #expect(StreakFreezeLogic.dateNeedingProtection(for: habit, today: Date(), calendar: calendar) == nil)
    }

    // MARK: - protect

    @Test func protectConsumesOneFreezePerEligibleHabit() {
        let habitA = Habit(name: "A", goal: "goal", color: "A78BFA", startDate: daysAgo(10))
        let habitB = Habit(name: "B", goal: "goal", color: "FFD700", startDate: daysAgo(10))
        for offset in 2...10 {
            habitA.completedDates.append(daysAgo(offset))
            habitB.completedDates.append(daysAgo(offset))
        }

        let wallet = FreezeWallet(freezesAvailable: 2, refillDate: daysAgo(-30))
        let (protectedPairs, newWallet) = StreakFreezeLogic.protect(
            habits: [habitA, habitB], wallet: wallet, isPremium: false, today: Date(), calendar: calendar
        )

        #expect(protectedPairs.count == 2)
        #expect(newWallet.freezesAvailable == 0)
    }

    @Test func protectStopsWhenWalletRunsOut() {
        let habitA = Habit(name: "A", goal: "goal", color: "A78BFA", startDate: daysAgo(10))
        let habitB = Habit(name: "B", goal: "goal", color: "FFD700", startDate: daysAgo(10))
        for offset in 2...10 {
            habitA.completedDates.append(daysAgo(offset))
            habitB.completedDates.append(daysAgo(offset))
        }

        let wallet = FreezeWallet(freezesAvailable: 1, refillDate: daysAgo(-30))
        let (protectedPairs, newWallet) = StreakFreezeLogic.protect(
            habits: [habitA, habitB], wallet: wallet, isPremium: false, today: Date(), calendar: calendar
        )

        #expect(protectedPairs.count == 1)
        #expect(protectedPairs.first?.habit.name == "A")
        #expect(newWallet.freezesAvailable == 0)
    }

    @Test func premiumNeverConsumesTheWallet() {
        let habitA = Habit(name: "A", goal: "goal", color: "A78BFA", startDate: daysAgo(10))
        let habitB = Habit(name: "B", goal: "goal", color: "FFD700", startDate: daysAgo(10))
        for offset in 2...10 {
            habitA.completedDates.append(daysAgo(offset))
            habitB.completedDates.append(daysAgo(offset))
        }

        let wallet = FreezeWallet(freezesAvailable: 0, refillDate: daysAgo(-30))
        let (protectedPairs, newWallet) = StreakFreezeLogic.protect(
            habits: [habitA, habitB], wallet: wallet, isPremium: true, today: Date(), calendar: calendar
        )

        #expect(protectedPairs.count == 2)
        #expect(newWallet.freezesAvailable == 0)
    }

    // MARK: - Habit streak/frozen interaction

    @Test func frozenDayContinuesCurrentStreakWithoutCountingAsCompletion() {
        let habit = Habit(name: "Meditate", goal: "10 min", color: "FFD700", startDate: daysAgo(5))
        habit.completedDates.append(daysAgo(5))
        habit.completedDates.append(daysAgo(4))
        habit.frozenDates.append(daysAgo(3))
        habit.completedDates.append(daysAgo(2))
        habit.completedDates.append(daysAgo(1))
        habit.completedDates.append(daysAgo(0))

        #expect(habit.currentStreak == 6)
        #expect(habit.totalCompletions == 5) // the frozen day doesn't count as a completion
    }

    @Test func frozenDayBreaksNothingButDoesNotExtendBestStreakAsACompletion() {
        let habit = Habit(name: "Meditate", goal: "10 min", color: "FFD700", startDate: daysAgo(3))
        habit.completedDates.append(daysAgo(3))
        habit.frozenDates.append(daysAgo(2))
        habit.completedDates.append(daysAgo(1))
        habit.completedDates.append(daysAgo(0))

        #expect(habit.bestStreak == 4)
    }
}
