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
        let entries = [
            JournalEntry(date: daysAgo(1), text: "yesterday"),
            JournalEntry(date: daysAgo(2), text: "two days ago")
        ]
        #expect(JournalLogic.currentStreak(entries: entries) == 2)
    }

    @Test func aGapBreaksTheStreak() {
        let entries = [
            JournalEntry(date: daysAgo(0), text: "today"),
            JournalEntry(date: daysAgo(2), text: "two days ago")
        ]
        #expect(JournalLogic.currentStreak(entries: entries) == 1)
    }

    @Test func missingBothTodayAndYesterdayIsZero() {
        let entries = [JournalEntry(date: daysAgo(2), text: "stale")]
        #expect(JournalLogic.currentStreak(entries: entries) == 0)
    }

    @Test func weekRibbonMarksTodayAndPastEntries() {
        let today = calendar.startOfDay(for: Date())
        let entries = [
            JournalEntry(date: today, text: "today"),
            JournalEntry(date: daysAgo(2), text: "two ago")
        ]
        let ribbon = JournalLogic.weekRibbon(entries: entries, today: today)
        #expect(ribbon.count == 7)
        #expect(ribbon.last?.isToday == true)
        #expect(ribbon.last?.hasEntry == true)
        #expect(ribbon[ribbon.count - 3].hasEntry == true) // daysAgo(2)
        #expect(ribbon[ribbon.count - 2].hasEntry == false) // daysAgo(1)
    }

    @Test func timelineSectionsGroupRelativeDays() {
        let today = calendar.startOfDay(for: Date())
        let entries = [
            JournalEntry(date: today, text: "t", createdAt: today),
            JournalEntry(date: daysAgo(1), text: "y"),
            JournalEntry(date: daysAgo(3), text: "w"),
            JournalEntry(date: daysAgo(20), text: "old")
        ]
        let sections = JournalLogic.timelineSections(entries: entries, today: today)
        let titles = sections.map(\.title)
        #expect(titles == ["Today", "Yesterday", "This week", "Earlier"])
    }

    @Test func uniqueDayCountDeduplicatesSameDay() {
        let today = calendar.startOfDay(for: Date())
        let entries = [
            JournalEntry(date: today, text: "a"),
            JournalEntry(date: today, text: "b"),
            JournalEntry(date: daysAgo(1), text: "c")
        ]
        #expect(JournalLogic.uniqueDayCount(entries: entries) == 2)
    }

    @Test func energyClampsOnInit() {
        #expect(JournalEntry(energy: 0).energy == 1)
        #expect(JournalEntry(energy: 9).energy == 5)
        #expect(JournalEntry(energy: 3).energy == 3)
    }
}
