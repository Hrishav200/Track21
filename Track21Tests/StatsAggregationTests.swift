//
//  StatsAggregationTests.swift
//  Track21Tests
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct StatsAggregationTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    // MARK: - dayStatusCounts

    @Test func dayStatusCountsTalliesAcrossMultipleHabits() {
        let water = Habit(name: "Water", goal: "8 glasses", color: "6BB6FF", startDate: daysAgo(2))
        water.completedDates = [daysAgo(2), daysAgo(1)]
        // daysAgo(0) missed, unprotected.

        let read = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(1))
        read.completedDates = [daysAgo(1)]
        read.frozenDates = [daysAgo(0)]

        let counts = StatsAggregation.dayStatusCounts(for: [water, read])

        #expect(counts.completed == 3)
        #expect(counts.frozen == 1)
        #expect(counts.missed == 1)
        #expect(counts.total == 5)
    }

    @Test func dayStatusCountsNeverCountsFutureDays() {
        let habit = Habit(name: "Water", goal: "8 glasses", color: "6BB6FF", startDate: daysAgo(0))
        // Brand new, nothing completed yet — today itself is the only
        // elapsed day, and it's unprotected/missed since it isn't done.

        let counts = StatsAggregation.dayStatusCounts(for: [habit])

        #expect(counts.total == 1)
        #expect(counts.missed == 1)
    }

    @Test func dayStatusCountsIsZeroForNoHabits() {
        let counts = StatsAggregation.dayStatusCounts(for: [])
        #expect(counts.total == 0)
    }

    // MARK: - longestCurrentStreak / bestStreakEver

    @Test func longestCurrentStreakPicksTheMaxAcrossHabits() {
        let water = Habit(name: "Water", goal: "8 glasses", color: "6BB6FF", startDate: daysAgo(4))
        water.completedDates = [daysAgo(4), daysAgo(3), daysAgo(2), daysAgo(1), daysAgo(0)]

        let read = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(1))
        read.completedDates = [daysAgo(1)]

        #expect(StatsAggregation.longestCurrentStreak(for: [water, read]) == 5)
    }

    @Test func bestStreakEverCanExceedTheCurrentStreak() {
        let habit = Habit(name: "Water", goal: "8 glasses", color: "6BB6FF", startDate: daysAgo(5))
        habit.completedDates = [daysAgo(5), daysAgo(4), daysAgo(3)]
        // Broke the streak — daysAgo(2) and daysAgo(1) missed, unprotected.
        habit.completedDates.append(daysAgo(0))

        #expect(StatsAggregation.bestStreakEver(for: [habit]) == 3)
        #expect(StatsAggregation.longestCurrentStreak(for: [habit]) == 1)
    }

    // MARK: - overallCompletionRate

    @Test func overallCompletionRateWeightsByElapsedDaysNotByHabitCount() {
        // 1 day old, 100% complete.
        let brandNew = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(0))
        brandNew.completedDates = [daysAgo(0)]

        // 20 days old (elapsed), 9 of them complete — 45%.
        let established = Habit(name: "Water", goal: "8 glasses", color: "6BB6FF", startDate: daysAgo(19))
        established.completedDates = (0...8).map { daysAgo($0) }

        let rate = StatsAggregation.overallCompletionRate(for: [brandNew, established])

        // 10 completed / 21 elapsed ≈ 0.476 — a plain average of the two
        // habits' percentages (100% and 45%) would wrongly land near 72%.
        #expect(abs(rate - (10.0 / 21.0)) < 0.001)
    }

    @Test func overallCompletionRateIsZeroForNoHabits() {
        #expect(StatsAggregation.overallCompletionRate(for: []) == 0)
    }
}
