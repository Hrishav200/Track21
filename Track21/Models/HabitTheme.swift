//
//  HabitTheme.swift
//  Track21
//
//  A habit's "theme" is its background colour (`Habit.color`, a 6-digit hex
//  string without #). These are the same six named presets the Add Habit
//  and Edit Habit screens offer, so Buddy can talk about them by name.
//

import Foundation

struct HabitTheme: Equatable, Hashable, Identifiable {
    let name: String
    let hex: String

    var id: String { hex }

    /// Same order and values as AddHabitView / EditHabitView `colors` + `colorNames`.
    static let all: [HabitTheme] = [
        HabitTheme(name: "Coral", hex: "FFB6A3"),
        HabitTheme(name: "Blue", hex: "6BB6FF"),
        HabitTheme(name: "Green", hex: "5DD167"),
        HabitTheme(name: "Gold", hex: "FFD700"),
        HabitTheme(name: "Pink", hex: "FF6B9D"),
        HabitTheme(name: "Purple", hex: "A78BFA"),
    ]

    /// AddHabitView's default selection.
    static let defaultTheme = all[0]

    /// Loose aliases so "yellow" or "red" still land on a preset.
    private static let aliases: [String: String] = [
        "orange": "Coral", "peach": "Coral", "salmon": "Coral", "red": "Coral",
        "yellow": "Gold", "golden": "Gold",
        "violet": "Purple", "lavender": "Purple", "lilac": "Purple",
        "rose": "Pink", "magenta": "Pink",
        "sky": "Blue", "navy": "Blue",
        "lime": "Green", "mint": "Green",
    ]

    /// Matches a theme by name, alias or hex (case-insensitive). Accepts
    /// phrases like "make it blue" or "#6BB6FF".
    static func matching(_ text: String) -> HabitTheme? {
        let lowered = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !lowered.isEmpty else { return nil }

        if let exact = all.first(where: { $0.name.lowercased() == lowered || $0.hex.lowercased() == lowered }) {
            return exact
        }

        let words = lowered
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for word in words {
            if let theme = all.first(where: { $0.name.lowercased() == word || $0.hex.lowercased() == word }) {
                return theme
            }
            if let aliasName = aliases[word], let theme = all.first(where: { $0.name == aliasName }) {
                return theme
            }
        }
        return nil
    }

    /// Display name for a stored hex, or "Custom" for colour-picker colours.
    static func name(forHex hex: String?) -> String {
        guard let hex else { return "Custom" }
        return all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? "Custom"
    }
}
