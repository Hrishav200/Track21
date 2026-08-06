//
//  BuddyLogicTests.swift
//  Track21Tests
//
//  Tests BuddyLogic's pure functions directly — no UserDefaults, no
//  UNUserNotificationCenter, no BuddyService singleton — fully deterministic.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct BuddyLogicTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    // MARK: - randomLine

    @Test func randomLinePicksExactIndexFromCategory() {
        let pool = BuddyLogic.lines[.general]!
        let line = BuddyLogic.randomLine(for: .general, pickIndex: 0)
        #expect(line == pool[0])
    }

    @Test func randomLineWrapsIndexWithinPoolBounds() {
        let pool = BuddyLogic.lines[.milestone]!
        let line = BuddyLogic.randomLine(for: .milestone, pickIndex: pool.count)
        #expect(line == pool[0])
    }

    // MARK: - category

    @Test func categoryIsMilestoneWhenTodaysStreakHitsAMilestoneNumber() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(7))
        for offset in 0...6 {
            habit.completedDates.append(daysAgo(offset))
        }
        // 7-day streak, completed today — should be a milestone.
        #expect(BuddyLogic.category(for: [habit], now: Date()) == .milestone)
    }

    @Test func categoryIsStreakAtRiskInTheEveningWithAnUnfinishedActiveStreak() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        for offset in 1...5 {
            habit.completedDates.append(daysAgo(offset))
        }
        // Not completed today, active streak, evening.
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        let evening = calendar.date(from: components)!

        #expect(BuddyLogic.category(for: [habit], now: evening) == .streakAtRisk)
    }

    @Test func categoryIsComebackAfterAMissedYesterdayWithNoActiveStreakToday() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(5))
        habit.completedDates.append(daysAgo(3))
        // Missed yesterday, and it's not evening, so streakAtRisk shouldn't fire.
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10
        let morning = calendar.date(from: components)!

        #expect(BuddyLogic.category(for: [habit], now: morning) == .comeback)
    }

    @Test func categoryFallsBackToGeneralWithNothingNotable() {
        // Starts today, so "yesterday" falls outside the habit's tracked
        // period entirely — nothing missed, nothing at risk, no streak yet.
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(0))
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10
        let morning = calendar.date(from: components)!

        #expect(BuddyLogic.category(for: [habit], now: morning) == .general)
    }

    // MARK: - isNudgeDue

    @Test func nudgeIsDueWhenThereWasNoPreviousNudge() {
        #expect(BuddyLogic.isNudgeDue(lastNudgeDate: nil, now: Date()) == true)
    }

    @Test func nudgeIsNotDueShortlyAfterThePreviousOne() {
        let now = Date()
        let recent = now.addingTimeInterval(-60 * 60) // 1 hour ago
        #expect(BuddyLogic.isNudgeDue(lastNudgeDate: recent, now: now) == false)
    }

    @Test func nudgeIsDueOnceTheMinimumIntervalHasPassed() {
        let now = Date()
        let longAgo = now.addingTimeInterval(-BuddyLogic.minimumNudgeInterval - 1)
        #expect(BuddyLogic.isNudgeDue(lastNudgeDate: longAgo, now: now) == true)
    }

    // MARK: - nextNudgeFireDate

    @Test func nextNudgeFireDateUsesInjectedOffset() {
        let now = Date()
        let fireDate = BuddyLogic.nextNudgeFireDate(now: now, randomOffsetHours: { 3.0 })
        #expect(abs(fireDate.timeIntervalSince(now) - 3 * 3600) < 1)
    }

    // MARK: - crisis safety net

    @Test func detectsObviousCrisisLanguage() {
        #expect(BuddyLogic.containsCrisisSignal("I want to kill myself") == true)
        #expect(BuddyLogic.containsCrisisSignal("sometimes I think about suicide") == true)
    }

    @Test func ordinaryMotivationTalkIsNotFlaggedAsCrisis() {
        #expect(BuddyLogic.containsCrisisSignal("I missed my streak and I feel bad") == false)
        #expect(BuddyLogic.containsCrisisSignal("This workout is killing me lol") == false)
    }
}
