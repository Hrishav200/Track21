//
//  JournalPrompts.swift
//  Track21
//
//  Habit-aware reflection prompts for the Journal composer. Keeps the
//  "what should I write?" friction near zero — especially mid-cycle when
//  a named habit + day number makes the question feel personal.
//

import Foundation

enum JournalPrompts {
    private static let evergreen: [String] = [
        "What tiny win are you proud of today?",
        "What made showing up a little easier?",
        "If today had a headline, what would it be?",
        "What do you want tomorrow-you to remember?",
        "Where did you feel strongest today?",
        "What would you tell a friend who had your day?",
        "Name one thing you're grateful you did — or didn't do.",
        "What slowed you down, and what helped anyway?",
        "How does your body feel right now — honestly?",
        "What are you becoming through these 21 days?"
    ]

    /// Picks a prompt. Prefer habit-personal when active habits exist;
    /// rotate via `seed` so shuffle feels intentional, not random-jittery.
    static func prompt(
        habits: [Habit],
        streak: Int,
        seed: Int,
        now: Date = Date()
    ) -> String {
        var pool = evergreen

        for habit in habits where habit.isInActiveCycle {
            let day = max(1, habit.currentDay)
            pool.append("How did \(habit.name) feel on day \(day)?")
            if !habit.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pool.append("Did \(habit.name) move you closer to \"\(habit.goal)\"?")
            }
            if habit.isCompletedToday() {
                pool.append("You checked off \(habit.name) — what helped you follow through?")
            } else {
                pool.append("Still time for \(habit.name) today. What's one small step?")
            }
        }

        if streak >= 3 {
            pool.append("You're on a \(streak)-day writing streak — what keeps you coming back?")
        }
        if streak >= 7 {
            pool.append("A full week of pages. What shifted in you?")
        }

        let hour = Calendar.current.component(.hour, from: now)
        if hour < 11 {
            pool.append("Morning check-in: what's your intention for today?")
        } else if hour >= 18 {
            pool.append("Evening wind-down: what deserves a quiet nod from today?")
        }

        guard !pool.isEmpty else { return evergreen[0] }
        let index = abs(seed) % pool.count
        return pool[index]
    }

    static func greeting(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Hey, night owl"
        }
    }
}
