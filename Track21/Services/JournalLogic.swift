//
//  JournalLogic.swift
//  Track21
//
//  Pure decision logic for the Journal tab — kept separate from
//  JournalService's UserDefaults plumbing so it's fully unit testable,
//  matching AchievementLogic/StreakFreezeLogic's split.
//

import Foundation

enum JournalLogic {
    /// Consecutive days (counting back from today) with a journal entry.
    /// Mirrors Habit.currentStreak's treatment of "today": a missing
    /// entry for today doesn't break a streak built up through yesterday,
    /// since today genuinely isn't over yet.
    static func currentStreak(entries: [JournalEntry], today: Date = Date(), calendar: Calendar = .current) -> Int {
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)

        if !entryDays.contains(day) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }

        var streak = 0
        while entryDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Last `count` calendar days oldest→newest with a hasEntry flag.
    static func weekRibbon(
        entries: [JournalEntry],
        count: Int = 7,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(date: Date, hasEntry: Bool, isToday: Bool)] {
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        let end = calendar.startOfDay(for: today)
        return (0..<count).compactMap { daysBeforeEnd in
            let offset = (count - 1) - daysBeforeEnd
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return (day, entryDays.contains(day), calendar.isDateInToday(day))
        }
    }

    /// Groups entries for the Memory Lane timeline.
    static func timelineSections(
        entries: [JournalEntry],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(title: String, entries: [JournalEntry])] {
        let startToday = calendar.startOfDay(for: today)
        let startYesterday = calendar.date(byAdding: .day, value: -1, to: startToday) ?? startToday
        let startWeek = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday

        var todayItems: [JournalEntry] = []
        var yesterdayItems: [JournalEntry] = []
        var weekItems: [JournalEntry] = []
        var earlierItems: [JournalEntry] = []

        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if day == startToday {
                todayItems.append(entry)
            } else if day == startYesterday {
                yesterdayItems.append(entry)
            } else if day >= startWeek {
                weekItems.append(entry)
            } else {
                earlierItems.append(entry)
            }
        }

        var result: [(String, [JournalEntry])] = []
        if !todayItems.isEmpty { result.append(("Today", todayItems)) }
        if !yesterdayItems.isEmpty { result.append(("Yesterday", yesterdayItems)) }
        if !weekItems.isEmpty { result.append(("This week", weekItems)) }
        if !earlierItems.isEmpty { result.append(("Earlier", earlierItems)) }
        return result
    }

    /// Distinct calendar days that have at least one entry.
    static func uniqueDayCount(entries: [JournalEntry], calendar: Calendar = .current) -> Int {
        Set(entries.map { calendar.startOfDay(for: $0.date) }).count
    }
}
