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
}
