//
//  BuddyLogic.swift
//  Track21
//
//  Pure decision logic for the accountability-buddy feature: which
//  pre-written line to send, when a nudge is due, and a client-side safety
//  net for crisis language. Kept free of UserDefaults/UNUserNotificationCenter
//  so it's fully unit testable, matching StreakFreezeLogic's split.
//

import Foundation

enum BuddyLineCategory: String, CaseIterable {
    case general
    case streakAtRisk
    case comeback
    case milestone
}

enum BuddyLogic {
    /// Below this gap since the last nudge, another one won't be scheduled.
    /// Deliberately under 24h so a nudge sent slightly earlier one day
    /// doesn't get pushed a full extra day the next.
    static let minimumNudgeInterval: TimeInterval = 20 * 60 * 60

    /// Streak lengths worth celebrating with a milestone line.
    static let milestoneStreaks: Set<Int> = [3, 7, 14, 21, 30, 50, 75, 100]

    static let lines: [BuddyLineCategory: [String]] = [
        .general: [
            "Small steps still count. Today's one of them.",
            "You don't have to be perfect — just show up.",
            "Future you is already proud of today you.",
            "One habit at a time. You're doing great.",
            "Consistency beats intensity. Keep going.",
            "I believe in you, even on the slow days.",
            "Progress, not perfection. That's the deal.",
            "You showed up yesterday. Show up again today.",
            "Every day you choose this, you're becoming someone new.",
            "This is your reminder that you're capable of more than you think.",
            "Discipline is just self-love in action.",
            "You're not behind. You're exactly where you need to be.",
            "Keep stacking the days — they add up faster than you think.",
            "A little bit today beats a lot tomorrow.",
            "I'm rooting for you today, same as every day.",
            "Growth is quiet. Keep going even when no one's clapping.",
            "You started this for a reason. Remember it today.",
            "Habits are just promises you keep to yourself.",
            "Today's a good day to be a little better than yesterday.",
            "You've got this. I mean it."
        ],
        .streakAtRisk: [
            "Don't let today slip — your streak is counting on you.",
            "Quick reminder: you haven't checked in yet today. Still time!",
            "Your streak is still alive. Let's keep it that way tonight.",
            "One small action tonight keeps the streak going.",
            "Hey — before the day ends, don't forget today's habit.",
            "You've come this far. Don't stop now.",
            "The day's not over. Neither is your streak.",
            "A few minutes now saves your streak later.",
            "Your future self will thank you for finishing today strong.",
            "Still time to keep the chain unbroken.",
            "Don't break the streak over something this small — go do it.",
            "This is your nudge: today's habit is still waiting.",
            "You didn't come this far to stop today.",
            "Last call — your streak needs you tonight.",
            "It takes two minutes. Your streak takes zero risk."
        ],
        .comeback: [
            "Yesterday happened. Today's a clean slate — let's go.",
            "Missing a day doesn't erase your progress. Get back in it.",
            "One off day doesn't define you. Come back stronger today.",
            "No guilt, just today. Let's restart together.",
            "The comeback is always stronger than the setback.",
            "You're allowed to miss a day. You're not allowed to quit.",
            "Let's pick it back up — I'm right here with you.",
            "A missed day is just a pause, not the end.",
            "Everyone slips. What matters is what you do next.",
            "Shake it off — today's a brand new shot.",
            "You've bounced back before. You can do it again.",
            "Progress isn't a straight line. Let's get back on track.",
            "I'm not going anywhere. Let's try again today.",
            "Yesterday doesn't get a vote in what you do today.",
            "Ready when you are. Let's make today count."
        ],
        .milestone: [
            "Look at you go — that's a milestone! Proud of you.",
            "You just hit a big one. Take a second to feel that.",
            "That streak number is no accident. That's you, showing up.",
            "Milestone unlocked. You earned this one.",
            "This is what consistency looks like. Amazing work.",
            "You should be really proud of this streak.",
            "That's a serious milestone — celebrate it a little.",
            "Every day added to this streak was a choice. Great choices.",
            "You're proof that small habits become big wins.",
            "This milestone didn't happen by luck. It happened by you.",
            "That's impressive. Seriously — well done.",
            "You just leveled up your streak game.",
            "I hope you know how far you've come.",
            "That number represents real, hard-earned consistency.",
            "Milestone hit. On to the next one — let's keep going."
        ]
    ]

    /// Picks which flavor of line fits today, in priority order: celebrate a
    /// milestone first, then chase down an at-risk streak, then coax back a
    /// missed one, falling back to general encouragement.
    static func category(for habits: [Habit], now: Date, calendar: Calendar = .current) -> BuddyLineCategory {
        let today = calendar.startOfDay(for: now)

        let hasMilestone = habits.contains { habit in
            habit.isCompletedToday() && milestoneStreaks.contains(habit.currentStreak(asOf: today))
        }
        if hasMilestone { return .milestone }

        let hour = calendar.component(.hour, from: now)
        let hasAtRiskStreak = hour >= 18 && habits.contains { habit in
            !habit.isCompletedToday() && habit.currentStreak(asOf: today) > 0
        }
        if hasAtRiskStreak { return .streakAtRisk }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return .general }
        let hasMissedYesterday = habits.contains { $0.dateStatus(for: yesterday) == .missed }
        if hasMissedYesterday { return .comeback }

        return .general
    }

    /// Deterministic given `pickIndex` (defaults to a random pick) so tests
    /// can assert an exact line without stubbing global randomness.
    static func randomLine(for category: BuddyLineCategory, pickIndex: Int? = nil) -> String {
        let pool = lines[category] ?? []
        guard !pool.isEmpty else { return "You've got this." }
        let index = pickIndex.map { $0 % pool.count } ?? Int.random(in: 0..<pool.count)
        return pool[index]
    }

    static func isNudgeDue(lastNudgeDate: Date?, now: Date) -> Bool {
        guard let lastNudgeDate else { return true }
        return now.timeIntervalSince(lastNudgeDate) >= minimumNudgeInterval
    }

    /// A time later today (or, past a cutoff hour, tomorrow) to fire the
    /// next nudge — spread out so it doesn't land at the exact same minute
    /// every day. `randomOffsetHours` is injectable for deterministic tests.
    static func nextNudgeFireDate(
        now: Date,
        calendar: Calendar = .current,
        randomOffsetHours: () -> Double = { Double.random(in: 2...9) }
    ) -> Date {
        calendar.date(byAdding: .second, value: Int(randomOffsetHours() * 3600), to: now) ?? now
    }

    // MARK: - Crisis safety net

    private static let crisisKeywords = [
        "kill myself", "want to die", "end my life", "suicide", "suicidal",
        "hurt myself", "self harm", "self-harm", "no reason to live", "not worth living"
    ]

    static func containsCrisisSignal(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return crisisKeywords.contains { lowered.contains($0) }
    }

    static let crisisResponse = """
    I care about you, but I'm not equipped to help with this — please reach out to people who are. \
    In the US, you can call or text 988 (Suicide & Crisis Lifeline) any time, day or night. \
    If you're outside the US, findahelpline.com has local numbers. You don't have to go through this alone.
    """
}
