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

    // MARK: - Habit management intent guard

    // The on-device model doesn't always follow the "only when asked"
    // instruction reliably (small models tend to over-suggest actions), so
    // this is a deterministic backstop: an action marker is only honored if
    // the user's own message actually asked for habit management. Requires a
    // management verb alongside "habit" so ordinary chat about habits
    // ("this habit is hard") doesn't trip it.
    private static let habitManagementVerbs = [
        "add", "create", "start tracking", "new habit",
        "delete", "remove", "drop", "cancel", "stop tracking", "quit", "get rid of",
        "update", "change", "edit", "rename", "modify", "adjust"
    ]

    static func requestsHabitManagement(_ text: String) -> Bool {
        let lowered = text.lowercased()
        guard lowered.contains("habit") else { return false }
        return habitManagementVerbs.contains { lowered.contains($0) }
    }

    // MARK: - Buddy Lite (templated chat when Foundation Models unavailable)

    enum BuddyLiteIntent: Equatable {
        case crisis
        case greeting
        case thanks
        case motivate
        case status
        case todayPlan
        case struggle
        case habitManagement
        case fallback
    }

    /// Snapshot of live habit state used to fill Lite reply templates.
    struct BuddyLiteContext: Equatable {
        var incompleteNames: [String]
        var completedNames: [String]
        var atRiskNames: [String]
        var habitNames: [String]
        var leadHabitName: String?
        var leadHabitDay: Int?
        var category: BuddyLineCategory

        var hasHabits: Bool { !habitNames.isEmpty }
        var allDoneToday: Bool { hasHabits && incompleteNames.isEmpty }
    }

    static func liteContext(
        for habits: [Habit],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BuddyLiteContext {
        let active = habits.filter(\.isInActiveCycle)
        let today = calendar.startOfDay(for: now)
        let incomplete = active.filter { !$0.isCompletedToday() }
        let completed = active.filter { $0.isCompletedToday() }
        let atRisk = incomplete.filter { $0.currentStreak(asOf: today) > 0 }
        let lead = active.max(by: { $0.currentDay < $1.currentDay })

        return BuddyLiteContext(
            incompleteNames: incomplete.map(\.name),
            completedNames: completed.map(\.name),
            atRiskNames: atRisk.map(\.name),
            habitNames: active.map(\.name),
            leadHabitName: lead?.name,
            leadHabitDay: lead?.currentDay,
            category: category(for: active, now: now, calendar: calendar)
        )
    }

    static func detectLiteIntent(_ text: String) -> BuddyLiteIntent {
        if containsCrisisSignal(text) { return .crisis }

        let lowered = text.lowercased()

        if requestsHabitManagement(text) { return .habitManagement }

        let motivateHints = ["motivate", "encourage", "inspire", "pep talk", "pump me", "hype"]
        if motivateHints.contains(where: { lowered.contains($0) }) { return .motivate }

        let statusHints = ["how am i", "how'm i", "progress", "streak", "status", "how's my", "hows my", "doing so far", "am i on track"]
        if statusHints.contains(where: { lowered.contains($0) }) { return .status }

        let planHints = ["what should", "what can i", "what do i", "today's plan", "todays plan", "help me start", "where do i start", "next step"]
        if planHints.contains(where: { lowered.contains($0) }) { return .todayPlan }

        let struggleHints = ["struggling", "hard today", "can't do", "cant do", "tired", "failed", "missed", "slipped", "gave up", "falling behind"]
        if struggleHints.contains(where: { lowered.contains($0) }) { return .struggle }

        let thanksHints = ["thank", "thanks", "thx", "appreciate"]
        if thanksHints.contains(where: { lowered.contains($0) }) { return .thanks }

        let greetings = ["hi", "hello", "hey", "yo", "good morning", "good afternoon", "good evening"]
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        if greetings.contains(where: { trimmed == $0 || trimmed.hasPrefix($0 + " ") || trimmed.hasPrefix($0 + "!") || trimmed.hasPrefix($0 + ",") }) {
            return .greeting
        }

        return .fallback
    }

    /// Habit-aware canned coaching. Crisis always wins. Deterministic when
    /// `pickIndex` is supplied so unit tests can pin an exact line.
    static func liteReply(
        to text: String,
        habits: [Habit],
        buddyName: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        pickIndex: Int? = nil
    ) -> String {
        let intent = detectLiteIntent(text)
        if intent == .crisis { return crisisResponse }

        let ctx = liteContext(for: habits, now: now, calendar: calendar)
        let pool = liteLines(intent: intent, context: ctx, buddyName: buddyName)
        guard !pool.isEmpty else {
            return randomLine(for: ctx.category, pickIndex: pickIndex)
        }
        let index = pickIndex.map { abs($0) % pool.count } ?? Int.random(in: 0..<pool.count)
        return pool[index]
    }

    static let liteQuickPrompts = [
        "Motivate me",
        "How am I doing?",
        "What should I do today?",
        "I missed yesterday",
        "Add a habit"
    ]

    /// Soft upgrade copy when the device *could* run full Buddy but isn't.
    static func liteSoftCTA(for reason: BuddyAvailability) -> String? {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings for full conversational Buddy."
        case .modelNotReady:
            return "Full Buddy is still waking up — Lite coaching is on for now."
        case .available:
            return nil
        case .deviceNotEligible, .unsupportedOS:
            return nil
        }
    }

    static func liteModeCaption(for reason: BuddyAvailability) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Buddy Lite · private habit coaching"
        case .modelNotReady:
            return "Buddy Lite · full Buddy waking up"
        case .deviceNotEligible:
            return "Buddy Lite · on-device coaching"
        case .unsupportedOS:
            return "Buddy Lite · needs iOS 26+ for full Buddy"
        case .available:
            return "Buddy Lite"
        }
    }

    // MARK: Lite template pools

    private static func liteLines(intent: BuddyLiteIntent, context: BuddyLiteContext, buddyName: String) -> [String] {
        let incomplete = joinedNames(context.incompleteNames)
        let completed = joinedNames(context.completedNames)
        let atRisk = joinedNames(context.atRiskNames)
        let habits = joinedNames(context.habitNames)
        let lead: String = {
            if let name = context.leadHabitName, let day = context.leadHabitDay {
                return "\(name) (day \(day)/21)"
            }
            return habits.isEmpty ? "your habits" : habits
        }()

        switch intent {
        case .crisis:
            return [crisisResponse]

        case .greeting:
            if context.allDoneToday {
                return [
                    "Hey! You've already knocked out \(completed) today — love that energy.",
                    "Hi! \(completed) is done. I'm proud of you already.",
                    "Hey there. Streaks looking solid — what's on your mind?"
                ]
            }
            if !context.incompleteNames.isEmpty {
                return [
                    "Hey! Still waiting on \(incomplete) today — want a plan?",
                    "Hi — I'm here. \(incomplete) is still open whenever you're ready.",
                    "Hey! Quick win idea: tick \(context.incompleteNames[0]) and we'll build from there."
                ]
            }
            return [
                "Hey! I'm \(buddyName) — what's on your mind today?",
                "Hi — ready when you are. Want motivation, a status check, or a plan?",
                "Hey! Tell me how today's going."
            ]

        case .thanks:
            return [
                "Anytime. I've got your back.",
                "You're welcome — now go keep that streak honest.",
                "Always. One more small win today if you can."
            ]

        case .motivate:
            if !context.atRiskNames.isEmpty {
                return [
                    "Don't let \(atRisk) slip — that streak worked hard for you. Two minutes is enough.",
                    "\(atRisk) is still alive. Finish strong and future-you will thank you.",
                    "You've already proven you can show up. Protect \(atRisk) tonight."
                ]
            }
            if context.allDoneToday {
                return [
                    "You're already done for today — that discipline is the whole game. Keep stacking.",
                    "All clear on \(completed). Rest proud, show up again tomorrow.",
                    "Look at you — \(completed) finished. That's what consistency feels like."
                ]
            }
            if !context.incompleteNames.isEmpty {
                return [
                    "Start with \(context.incompleteNames[0]). Small step, real progress.",
                    "\(incomplete) is still waiting — pick one and move. Momentum beats mood.",
                    "You don't need a perfect day. You need \(context.incompleteNames[0]) done."
                ]
            }
            return [
                randomLine(for: .general, pickIndex: 0),
                randomLine(for: .general, pickIndex: 1),
                randomLine(for: .general, pickIndex: 2)
            ]

        case .status:
            if !context.hasHabits {
                return [
                    "No active habits yet — add one on Home and I'll coach you through the 21 days.",
                    "Blank slate! Create a habit and I'll track the streaks with you."
                ]
            }
            if context.allDoneToday {
                return [
                    "Status: green. \(completed) done today. \(lead) is your furthest cycle — keep going.",
                    "You're clear for today. Active: \(habits). Nice work.",
                    "All habits checked. Closest to the finish line: \(lead)."
                ]
            }
            var lines = [
                "Today: done \(completed.isEmpty ? "nothing yet" : completed). Still open: \(incomplete).",
                "Open checklist: \(incomplete). Closest to day 21: \(lead)."
            ]
            if !context.atRiskNames.isEmpty {
                lines.append("Streak watch: \(atRisk) needs you before midnight.")
            }
            return lines

        case .todayPlan:
            if !context.hasHabits {
                return [
                    "Plan: add one habit you actually care about, then check in with me after you tick day 1.",
                    "Start simple — one habit on Home, then come back and we'll build the streak together."
                ]
            }
            if context.allDoneToday {
                return [
                    "Plan: you're done. Optional — jot a journal page so tomorrow starts clearer.",
                    "Nothing left on the board. Protect the win: sleep well, same time tomorrow."
                ]
            }
            let first = context.incompleteNames[0]
            return [
                "Plan: do \(first) first. Then \(incomplete). One at a time.",
                "Open Track21 Home, tick \(first), and message me when it's done — I'll celebrate with you.",
                "Smallest useful step: \(first). Don't wait for motivation; start, then feel it."
            ]

        case .struggle:
            if context.category == .comeback || textSuggestsMiss(context: context) {
                return [
                    "Yesterday happened. Today is a clean slate — pick \(context.incompleteNames.first ?? "one habit") and restart without guilt.",
                    "Missing a day doesn't erase progress. Comeback mode: just show up once today.",
                    "No lecture. One tick today beats a perfect plan you don't start."
                ]
            }
            if !context.incompleteNames.isEmpty {
                return [
                    "Hard days count too. Shrink it: just \(context.incompleteNames[0]).",
                    "When it feels heavy, do the smallest version of \(context.incompleteNames[0]). Still counts.",
                    "I'm not going anywhere. \(incomplete) can wait five minutes — then we move."
                ]
            }
            return [
                randomLine(for: .comeback, pickIndex: 0),
                randomLine(for: .comeback, pickIndex: 1),
                randomLine(for: .general, pickIndex: 3)
            ]

        case .habitManagement:
            return [
                "Want to add or change a habit? Say \u{201C}add a habit\u{201D} or \u{201C}rename Walk to Run\u{201D} and I'll walk you through it, or use Add Habit on Home.",
                "I can set up or edit a habit with you right here. Try \u{201C}add a habit\u{201D}. Deleting still happens on Home.",
                "Say \u{201C}add a habit\u{201D} or \u{201C}change the goal of Walk\u{201D} and I'll guide you. To delete one, long-press it on Home."
            ]

        case .fallback:
            // Lean on the same category logic as nudges, then personalize.
            switch context.category {
            case .streakAtRisk:
                return [
                    "Heads-up: \(atRisk.isEmpty ? incomplete : atRisk) still needs you today.",
                    randomLine(for: .streakAtRisk, pickIndex: 0),
                    "You've got time. Start with \(context.incompleteNames.first ?? "your habit")."
                ]
            case .comeback:
                return [
                    randomLine(for: .comeback, pickIndex: 0),
                    "Fresh day. \(incomplete.isEmpty ? "Show up once." : "Tick \(context.incompleteNames[0]) and the comeback begins.")",
                    randomLine(for: .comeback, pickIndex: 2)
                ]
            case .milestone:
                return [
                    randomLine(for: .milestone, pickIndex: 0),
                    "That milestone on \(lead) is real. Feel it — then keep the chain going.",
                    randomLine(for: .milestone, pickIndex: 3)
                ]
            case .general:
                if !context.incompleteNames.isEmpty {
                    return [
                        "I'm with you. \(incomplete) is still open whenever you're ready.",
                        "Want a nudge, a status check, or a plan? Or just tick \(context.incompleteNames[0]).",
                        randomLine(for: .general, pickIndex: 4)
                    ]
                }
                return [
                    randomLine(for: .general, pickIndex: 0),
                    "I'm here — ask for motivation, progress, or what to do next.",
                    randomLine(for: .general, pickIndex: 5)
                ]
            }
        }
    }

    private static func textSuggestsMiss(context: BuddyLiteContext) -> Bool {
        context.category == .comeback
    }

    private static func joinedNames(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names.last!)"
        }
    }
}
