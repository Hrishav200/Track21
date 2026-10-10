//
//  HabitVictoryLogicTests.swift
//  Track21Tests
//
//  Tests HabitVictoryLogic's pure functions directly — no UserDefaults, no
//  HabitVictoryService singleton, matching AchievementLogicTests' split
//  (the singleton's "fires once" persistence isn't unit tested here since
//  Swift Testing runs test methods concurrently by default, and racing on
//  shared UserDefaults state would make that flaky rather than the logic
//  actually being wrong).
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct HabitVictoryLogicTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    /// A habit whose 21-day window started `startOffset` days ago.
    private func habit(startOffset: Int = 20) -> Habit {
        Habit(name: "Read", goal: "20 pages", color: "A78BFA", startDate: daysAgo(startOffset))
    }

    // MARK: - hasCompletedCycle / isPerfectCycle

    @Test func cycleIsNotCompleteWithFewerThan21DaysAccountedFor() {
        let h = habit()
        for offset in 1...20 { h.completedDates.append(daysAgo(offset)) }
        // Day 0 (today) intentionally left uncompleted — only 20/21 done.
        #expect(HabitVictoryLogic.hasCompletedCycle(h) == false)
    }

    @Test func cycleIsCompleteOnceAll21DaysAreCompleted() {
        let h = habit()
        for offset in 0...20 { h.completedDates.append(daysAgo(offset)) }
        #expect(HabitVictoryLogic.hasCompletedCycle(h) == true)
        #expect(HabitVictoryLogic.isPerfectCycle(h) == true)
    }

    @Test func cycleIsCompleteWithAMixOfCompletionsAndFreezes() {
        let h = habit()
        for offset in 1...20 { h.completedDates.append(daysAgo(offset)) }
        h.frozenDates.append(daysAgo(0))
        #expect(HabitVictoryLogic.hasCompletedCycle(h) == true)
        // Not perfect — one of the 21 days was a freeze, not a real completion.
        #expect(HabitVictoryLogic.isPerfectCycle(h) == false)
    }

    @Test func emptyHabitWithNoHistoryHasNotCompletedACycle() {
        let h = habit()
        #expect(HabitVictoryLogic.hasCompletedCycle(h) == false)
        #expect(HabitVictoryLogic.isPerfectCycle(h) == false)
    }
}
