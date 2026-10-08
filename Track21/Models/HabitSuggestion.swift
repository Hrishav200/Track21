//
//  HabitSuggestion.swift
//  Track21
//
//  One combined model for Add Habit suggestions: each habit title is linked
//  to its own description and SF Symbol icon. Matching / auto-fill rules live
//  in HabitSuggestionMatcher so they can be unit tested without SwiftUI.
//

import Foundation

struct HabitSuggestion: Identifiable, Hashable {
    let title: String
    let description: String
    let icon: String

    var id: String { title }
}

extension HabitSuggestion {
    static let all: [HabitSuggestion] = [
        HabitSuggestion(title: "Cold shower",
                        description: "Do the hard thing on command.",
                        icon: "drop"),
        HabitSuggestion(title: "Deep Focus",
                        description: "One distraction-free block on your top task.",
                        icon: "scope"),
        HabitSuggestion(title: "Evening Phone Cutoff",
                        description: "No scrolling before bed. Protect your sleep.",
                        icon: "iphone.slash"),
        HabitSuggestion(title: "Next day preparation",
                        description: "Plan tomorrow tonight. Zero morning friction.",
                        icon: "checklist"),
        HabitSuggestion(title: "Walk",
                        description: "Get outside, move, and clear your head.",
                        icon: "figure.walk"),
        HabitSuggestion(title: "Exercise",
                        description: "Show up, sweat, and get stronger.",
                        icon: "dumbbell"),
        HabitSuggestion(title: "Drink Water",
                        description: "Hydrate first. Fuel energy and focus.",
                        icon: "waterbottle"),
        HabitSuggestion(title: "Read",
                        description: "A few pages a day compounds.",
                        icon: "book"),
        HabitSuggestion(title: "Meditate",
                        description: "Sit, breathe, and quiet the noise.",
                        icon: "brain.head.profile"),
        HabitSuggestion(title: "Stretch",
                        description: "Stay loose, mobile, and pain-free.",
                        icon: "figure.flexibility"),
        HabitSuggestion(title: "Sleep 8 Hours",
                        description: "Full nights power everything else.",
                        icon: "bed.double"),
        HabitSuggestion(title: "No Sugar",
                        description: "Cut the crash. Keep energy steady.",
                        icon: "nosign"),
        HabitSuggestion(title: "Journal",
                        description: "Get your thoughts on paper. Reset.",
                        icon: "book.closed"),
        HabitSuggestion(title: "Take Vitamins",
                        description: "Small daily dose, long-term payoff.",
                        icon: "pills"),
        HabitSuggestion(title: "Practice Gratitude",
                        description: "Name what's going right today.",
                        icon: "heart"),
        HabitSuggestion(title: "Eat Vegetables",
                        description: "Fill your plate with real greens.",
                        icon: "leaf"),
        HabitSuggestion(title: "Learn Something",
                        description: "Get a little smarter every day.",
                        icon: "lightbulb"),
        HabitSuggestion(title: "Digital Detox",
                        description: "Step away from screens. Reclaim focus.",
                        icon: "wifi.slash"),
        // "Deep Work" was removed as a duplicate of "Deep Focus".
    ]
}

enum HabitSuggestionMatcher {
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Exact (case-insensitive, trimmed) title match.
    static func suggestion(matching name: String,
                           in suggestions: [HabitSuggestion] = HabitSuggestion.all) -> HabitSuggestion? {
        let key = normalized(name)
        guard !key.isEmpty else { return nil }
        return suggestions.first { normalized($0.title) == key }
    }

    /// The description is "safe" to replace only if it's empty or still equals
    /// a description that was auto-filled from a suggestion (never user text).
    static func canReplace(description: String, lastAutoFilled: String?) -> Bool {
        let current = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { return true }
        guard let lastAutoFilled else { return false }
        return description == lastAutoFilled
    }

    /// Returns the description to show after the name changed, or nil to leave it untouched.
    static func autoFilledDescription(forName name: String,
                                      currentDescription: String,
                                      lastAutoFilled: String?,
                                      in suggestions: [HabitSuggestion] = HabitSuggestion.all) -> String? {
        guard let match = suggestion(matching: name, in: suggestions),
              canReplace(description: currentDescription, lastAutoFilled: lastAutoFilled)
        else { return nil }
        return match.description
    }
}
