//
//  AchievementLogicTests.swift
//  Track21Tests
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct AchievementLogicTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    private func bounceBack(in habits: [Habit]) -> Bool {
        AchievementLogic.evaluate(habits: habits, chatDayCount: 0)
            .first { $0.id == "bounce_back" }?.isUnlocked ?? false
    }

    // MARK: - Bounce Back

    /// Regression: today isn't over yet, so Habit.dateStatus(for:) reports
    /// today as .missed (it's only .future for days after today) — that
    /// used to make hasBounceBack scan today itself and false-positive on
    /// a clean streak that simply hadn't been checked off for today yet.
    @Test func bounceBackDoesNotTriggerJustBecauseTodayIsntCompletedYet() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        for offset in 1...5 {
            habit.completedDates.append(daysAgo(offset))
        }
        // Today deliberately left uncompleted.

        #expect(bounceBack(in: [habit]) == false)
    }

    @Test func bounceBackTriggersAfterARealUnprotectedMissFollowedByARebuiltStreak() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(7))
        habit.completedDates.append(daysAgo(7))
        // daysAgo(6) missed, unprotected — the real bounce.
        for offset in 0...5 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(bounceBack(in: [habit]) == true)
    }

    @Test func bounceBackDoesNotTriggerWithoutAnyHistoricalMiss() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        for offset in 0...5 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(bounceBack(in: [habit]) == false)
    }

    @Test func bounceBackDoesNotTriggerWithoutAtLeastAThreeDayStreak() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        habit.completedDates.append(daysAgo(5))
        // daysAgo(4) and daysAgo(3) missed
        habit.completedDates.append(daysAgo(2))
        // Only a 1-day (partial today-shifted) streak since — not enough.

        #expect(bounceBack(in: [habit]) == false)
    }

    /// A freeze converts a missed day to .frozen, not .missed — a habit
    /// whose only "miss" was actually protected shouldn't count as ever
    /// having broken.
    @Test func bounceBackDoesNotCountAFrozenDayAsAMiss() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        habit.completedDates.append(daysAgo(5))
        habit.frozenDates.append(daysAgo(4))
        for offset in 0...3 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(bounceBack(in: [habit]) == false)
    }
}
