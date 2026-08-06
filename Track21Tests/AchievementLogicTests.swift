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

    private func perfectWeek(in habits: [Habit]) -> Bool {
        AchievementLogic.evaluate(habits: habits, chatDayCount: 0)
            .first { $0.id == "perfect_week" }?.isUnlocked ?? false
    }

    // MARK: - Perfect Week

    /// Regression: a habit started today that only had *today* to be
    /// completed was unlocking Perfect Week off a single day, because the
    /// other 6 days (before the habit existed) were skipped as "not active"
    /// instead of failing the check.
    @Test func perfectWeekDoesNotTriggerForABrandNewHabitCompletedOnce() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(0))
        habit.completedDates.append(daysAgo(0))

        #expect(perfectWeek(in: [habit]) == false)
    }

    /// Same bug, slightly older habit: 3 days of real history is still
    /// short of the 7 the achievement promises.
    @Test func perfectWeekDoesNotTriggerForAHabitYoungerThanSevenDays() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(2))
        for offset in 0...2 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(perfectWeek(in: [habit]) == false)
    }

    @Test func perfectWeekTriggersOnceAllSevenDaysAreCompletedOrFrozen() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(6))
        habit.frozenDates.append(daysAgo(6))
        for offset in 0...5 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(perfectWeek(in: [habit]) == true)
    }

    @Test func perfectWeekFailsIfAnyOfTheSevenDaysWasMissed() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(6))
        // daysAgo(6) missed, unprotected.
        for offset in 0...5 {
            habit.completedDates.append(daysAgo(offset))
        }

        #expect(perfectWeek(in: [habit]) == false)
    }

    /// A second habit added mid-week shouldn't retroactively require itself
    /// on days before it existed — only the older habit needs to be clean
    /// on those earlier days.
    @Test func perfectWeekOnlyRequiresHabitsThatExistedOnAGivenDay() {
        let older = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(6))
        let newer = Habit(name: "Stretch", goal: "10 min", color: "5DD167", startDate: daysAgo(2))
        for offset in 0...6 {
            older.completedDates.append(daysAgo(offset))
        }
        for offset in 0...2 {
            newer.completedDates.append(daysAgo(offset))
        }

        #expect(perfectWeek(in: [older, newer]) == true)
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
