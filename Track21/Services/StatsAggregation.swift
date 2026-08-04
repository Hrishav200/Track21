//
//  StatsAggregation.swift
//  Track21
//
//  Pure math for the Stats tab's "All" overview — rolling every habit's
//  day-by-day history into one aggregate picture instead of one habit's.
//  Kept separate from the views so the day-counting (easy to get an
//  off-by-one wrong in, as Perfect Week's isPerfectWeek proved) is unit
//  testable on its own.
//

import Foundation

enum StatsAggregation {
    struct DayStatusCounts {
        var completed = 0
        var frozen = 0
        var missed = 0

        var total: Int { completed + frozen + missed }
    }

    /// Tallies every habit's elapsed days (start through today or the
    /// habit's end, whichever is sooner) into a single Completed/Frozen/
    /// Missed count. Future/upcoming days are never counted — there's
    /// nothing to report on them yet.
    static func dayStatusCounts(
        for habits: [Habit], today: Date = Date(), calendar: Calendar = .current
    ) -> DayStatusCounts {
        var counts = DayStatusCounts()
        for habit in habits {
            let start = calendar.startOfDay(for: habit.startDate)
            let end = calendar.startOfDay(for: min(today, habit.endDate))
            guard end >= start else { continue }

            var day = start
            while day <= end {
                switch habit.dateStatus(for: day) {
                case .completed: counts.completed += 1
                case .frozen: counts.frozen += 1
                case .missed: counts.missed += 1
                case .future, .outside: break
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return counts
    }

    /// The longest streak currently running among active habits — the
    /// aggregate stand-in for a single habit's "Day Streak" tile.
    static func longestCurrentStreak(for habits: [Habit], today: Date = Date()) -> Int {
        habits.filter(\.isActive).map { $0.currentStreak(asOf: today) }.max() ?? 0
    }

    /// The best streak ever reached by any habit — the aggregate stand-in
    /// for a single habit's "Best Streak" tile.
    static func bestStreakEver(for habits: [Habit]) -> Int {
        habits.map(\.bestStreak).max() ?? 0
    }

    /// Total completions across every habit divided by total elapsed days
    /// across every habit — a single completion rate weighted by how long
    /// each habit has actually been running, not a plain average of
    /// per-habit percentages (which would let a 1-day-old habit at 100%
    /// count the same as a 20-day habit at 90%).
    static func overallCompletionRate(for habits: [Habit]) -> Double {
        let totalElapsed = habits.reduce(0) { $0 + $1.elapsedDaysCount }
        guard totalElapsed > 0 else { return 0 }
        let totalCompleted = habits.reduce(0) { $0 + $1.totalCompletions }
        return Double(totalCompleted) / Double(totalElapsed)
    }
}
