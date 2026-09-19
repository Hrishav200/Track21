//
//  JournalLogicTests.swift
//  Track21Tests
//
//  Tests JournalLogic's pure functions directly — no UserDefaults, no
//  JournalService singleton — matching the rest of the *Logic test split.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct JournalLogicTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    @Test func streakIsZeroWithNoEntries() {
        #expect(JournalLogic.currentStreak(entries: []) == 0)
    }

    @Test func streakCountsConsecutiveDaysEndingToday() {
        let entries = (0...2).map { JournalEntry(date: daysAgo($0), text: "day \($0)") }
        #expect(JournalLogic.currentStreak(entries: entries) == 3)
    }

    @Test func missingTodayDoesNotBreakAStreakBuiltThroughYesterday() {
        // Today hasn't been journaled yet, but yesterday/the day before have —
        // matches Habit.currentStreak's "today isn't over yet" treatment.
        let entries = [
            JournalEntry(date: daysAgo(1), text: "yesterday"),
            JournalEntry(date: daysAgo(2), text: "two days ago")
        ]
        #expect(JournalLogic.currentStreak(entries: entries) == 2)
    }

    @Test func aGapBreaksTheStreak() {
        let entries = [
            JournalEntry(date: daysAgo(0), text: "today"),
            // daysAgo(1) missing
            JournalEntry(date: daysAgo(2), text: "two days ago")
        ]
        #expect(JournalLogic.currentStreak(entries: entries) == 1)
    }

    @Test func missingBothTodayAndYesterdayIsZero() {
        let entries = [JournalEntry(date: daysAgo(2), text: "stale")]
        #expect(JournalLogic.currentStreak(entries: entries) == 0)
    }
}
