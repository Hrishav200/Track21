//
//  HabitVictoryLogic.swift
//  Track21
//
//  Pure decision logic for the "finished your 21-day cycle" celebration.
//  Deliberately separate from AchievementLogic's `cycle_complete`/`purist`
//  badges: those only unlock the day *after* the cycle window fully closes
//  (`!habit.isActive`), so the permanent badge record can't be granted then
//  un-granted if the user edits a past day before the window closes. This
//  celebration is a one-off UX moment, not a permanent record, so it fires
//  the instant all 21 days are accounted for — typically the moment the
//  user checks off day 21 itself.
//

import Foundation

enum HabitVictoryLogic {
    /// True once every day in the habit's 21-day window is either completed
    /// or protected by a streak freeze — i.e. the cycle finished clean, with
    /// no unprotected miss anywhere in it.
    static func hasCompletedCycle(_ habit: Habit) -> Bool {
        habit.totalCompletions + habit.totalFrozen >= 21
    }

    /// True if every single day was an actual completion — no freezes used.
    static func isPerfectCycle(_ habit: Habit) -> Bool {
        habit.totalCompletions >= 21
    }
}
