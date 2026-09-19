//
//  AchievementLogic.swift
//  Track21
//
//  Pure decision logic for badges — every achievement here is derived
//  entirely from data already tracked (habits, freezes, chat activity), no
//  new sync columns needed. Kept separate from AchievementService's
//  UserDefaults plumbing so it's fully unit testable.
//

import Foundation

enum AchievementLogic {
    static func evaluate(
        habits: [Habit],
        chatDayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [Achievement] {
        let maxBestStreak = habits.map(\.bestStreak).max() ?? 0
        let totalFreezesUsed = habits.reduce(0) { $0 + $1.frozenDates.count }
        let activeHabitsWithStreak = habits.filter { $0.isActive && $0.currentStreak(asOf: today) >= 1 }.count

        let hasCycleComplete = habits.contains { habit in
            !habit.isActive && habit.totalCompletions + habit.totalFrozen == 21
        }
        let hasPurist = habits.contains { habit in
            !habit.isActive && habit.totalCompletions == 21
        }
        let hasBounceBackBadge = habits.contains { hasBounceBack($0, today: today, calendar: calendar) }
        let perfectWeek = isPerfectWeek(habits: habits, today: today, calendar: calendar)

        return [
            streakBadge(id: "streak_3", title: "Spark", emoji: "🔥", threshold: 3, maxBestStreak: maxBestStreak, descriptionNoun: "a 3-day streak"),
            streakBadge(id: "streak_7", title: "Momentum", emoji: "🔥", threshold: 7, maxBestStreak: maxBestStreak, descriptionNoun: "a 7-day streak"),
            streakBadge(id: "streak_14", title: "Grind", emoji: "🔥", threshold: 14, maxBestStreak: maxBestStreak, descriptionNoun: "a 14-day streak"),
            streakBadge(id: "streak_50", title: "Long Hauler", emoji: "💎", threshold: 50, maxBestStreak: maxBestStreak, descriptionNoun: "a 50-day streak"),

            Achievement(
                id: "cycle_complete",
                title: "Cycle Complete",
                emoji: "🏆",
                lockedDescription: "Finish a full 21-day habit cycle without a single unprotected miss.",
                unlockedDescription: "Finished a full 21-day habit cycle without a single unprotected miss.",
                progressCurrent: hasCycleComplete ? 1 : 0,
                progressTarget: 1,
                isUnlocked: hasCycleComplete,
                unlockedDate: nil
            ),
            Achievement(
                id: "purist",
                title: "Purist",
                emoji: "⭐",
                lockedDescription: "Finish a 21-day cycle at 100% — every single day completed, no freezes needed.",
                unlockedDescription: "Finished a 21-day cycle at 100% — every single day completed, no freezes needed.",
                progressCurrent: hasPurist ? 1 : 0,
                progressTarget: 1,
                isUnlocked: hasPurist,
                unlockedDate: nil
            ),
            Achievement(
                id: "freeze_first",
                title: "First Freeze",
                emoji: "❄️",
                lockedDescription: "Use a streak freeze to protect a habit for the first time.",
                unlockedDescription: "Used a streak freeze to protect a habit for the first time.",
                progressCurrent: min(totalFreezesUsed, 1),
                progressTarget: 1,
                isUnlocked: totalFreezesUsed >= 1,
                unlockedDate: nil
            ),
            Achievement(
                id: "freeze_veteran",
                title: "Freeze Veteran",
                emoji: "🛡️",
                lockedDescription: "Use 5 streak freezes in total across all your habits.",
                unlockedDescription: "Used 5 streak freezes in total across all your habits.",
                progressCurrent: min(totalFreezesUsed, 5),
                progressTarget: 5,
                isUnlocked: totalFreezesUsed >= 5,
                unlockedDate: nil
            ),
            Achievement(
                id: "perfect_week",
                title: "Perfect Week",
                emoji: "✅",
                lockedDescription: "Complete every active habit, every day, for 7 days straight.",
                unlockedDescription: "Completed every active habit, every day, for 7 days straight.",
                progressCurrent: perfectWeek ? 7 : 0,
                progressTarget: 7,
                isUnlocked: perfectWeek,
                unlockedDate: nil
            ),
            Achievement(
                id: "multi_tasker",
                title: "Multi-Tasker",
                emoji: "🎯",
                lockedDescription: "Keep a streak going on 3 habits at the same time.",
                unlockedDescription: "Kept a streak going on 3 habits at the same time.",
                progressCurrent: min(activeHabitsWithStreak, 3),
                progressTarget: 3,
                isUnlocked: activeHabitsWithStreak >= 3,
                unlockedDate: nil
            ),
            Achievement(
                id: "bounce_back",
                title: "Bounce Back",
                emoji: "🔄",
                lockedDescription: "Rebuild a 3-day streak on a habit after missing a day.",
                unlockedDescription: "Rebuilt a 3-day streak on a habit after missing a day.",
                progressCurrent: hasBounceBackBadge ? 1 : 0,
                progressTarget: 1,
                isUnlocked: hasBounceBackBadge,
                unlockedDate: nil
            ),
            Achievement(
                id: "chat_broke_ice",
                title: "Broke the Ice",
                emoji: "💬",
                lockedDescription: "Send your first message to your Buddy.",
                unlockedDescription: "Sent your first message to your Buddy.",
                progressCurrent: min(chatDayCount, 1),
                progressTarget: 1,
                isUnlocked: chatDayCount >= 1,
                unlockedDate: nil
            ),
            Achievement(
                id: "chat_regular",
                title: "Regular Check-in",
                emoji: "🗓️",
                lockedDescription: "Chat with your Buddy on 7 different days.",
                unlockedDescription: "Chatted with your Buddy on 7 different days.",
                progressCurrent: min(chatDayCount, 7),
                progressTarget: 7,
                isUnlocked: chatDayCount >= 7,
                unlockedDate: nil
            )
        ]
    }

    private static func streakBadge(
        id: String, title: String, emoji: String, threshold: Int, maxBestStreak: Int, descriptionNoun: String
    ) -> Achievement {
        Achievement(
            id: id,
            title: title,
            emoji: emoji,
            lockedDescription: "Reach \(descriptionNoun) on any habit.",
            unlockedDescription: "Reached \(descriptionNoun) on a habit.",
            progressCurrent: min(maxBestStreak, threshold),
            progressTarget: threshold,
            isUnlocked: maxBestStreak >= threshold,
            unlockedDate: nil
        )
    }

    /// True if, for every day in the last 7, every habit that was active
    /// that day was completed or frozen — and at least one habit actually
    /// existed across that whole window (an empty habit list, or one too
    /// new to have 7 days of history, doesn't trivially qualify).
    private static func isPerfectWeek(habits: [Habit], today: Date, calendar: Calendar) -> Bool {
        guard !habits.isEmpty else { return false }
        let todayStart = calendar.startOfDay(for: today)

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return false }
            let activeThatDay = habits.filter {
                day >= calendar.startOfDay(for: $0.startDate) && day <= calendar.startOfDay(for: $0.endDate)
            }
            // A day with no active habit yet means the habit(s) haven't
            // existed for a full 7-day window. Previously this `continue`d
            // past the day instead of failing it, so a habit started today
            // and completed once would trivially satisfy "7 days straight"
            // — the other 6 days were silently skipped as "not active" and
            // never actually checked.
            guard !activeThatDay.isEmpty else { return false }
            let allGood = activeThatDay.allSatisfy {
                let status = $0.dateStatus(for: day)
                return status == .completed || status == .frozen
            }
            guard allGood else { return false }
        }
        return true
    }

    /// True if the habit currently has at least a 3-day streak, but also
    /// has at least one missed (unprotected) day earlier in its window —
    /// i.e. it broke at some point and has since been rebuilt.
    private static func hasBounceBack(_ habit: Habit, today: Date, calendar: Calendar) -> Bool {
        guard habit.currentStreak(asOf: today) >= 3 else { return false }
        let start = calendar.startOfDay(for: habit.startDate)
        let todayStart = calendar.startOfDay(for: today)
        // Never scan today itself — Habit.dateStatus(for:) reports .missed
        // for a today that hasn't been completed yet (it's only .future for
        // days strictly after today), since today genuinely isn't done. A
        // day still in progress isn't a "missed" day for this check.
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return false }
        let end = min(yesterday, calendar.startOfDay(for: habit.endDate))
        guard end >= start else { return false }

        var day = start
        while day <= end {
            if habit.dateStatus(for: day) == .missed { return true }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return false
    }
}
