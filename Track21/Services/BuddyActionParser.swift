//
//  BuddyActionParser.swift
//  Track21
//
//  Parses AI buddy responses for embedded action markers. Since Apple's
//  FoundationModels doesn't support tool/function calling, we use structured
//  text markers that the model outputs and this parser extracts.
//
//  Marker formats:
//    [ACTION:ADD_HABIT name="X" goal="Y" color="RRGGBB"]
//    [ACTION:UPDATE_HABIT name="X" newGoal="Y"]
//    [ACTION:DELETE_HABIT name="X"]
//

import Foundation

struct BuddyActionParser {

    struct ParseResult {
        let cleanedText: String
        let action: BuddyAction?
    }

    /// Parses a buddy response for action markers, returning cleaned text and any extracted action.
    /// - Parameters:
    ///   - response: The raw AI response potentially containing an action marker.
    ///   - habits: Current habits list, used to resolve habit names to IDs for update/delete.
    /// - Returns: A ParseResult with the marker removed from text and the action (if any).
    static func parse(_ response: String, habits: [Habit]) -> ParseResult {
        // Match [ACTION:TYPE key="value" ...] patterns
        let pattern = #"\[ACTION:(ADD_HABIT|UPDATE_HABIT|DELETE_HABIT)([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            return ParseResult(cleanedText: response, action: nil)
        }

        // Extract the action type
        guard let typeRange = Range(match.range(at: 1), in: response) else {
            return ParseResult(cleanedText: response, action: nil)
        }
        let typeString = String(response[typeRange])

        // Extract the parameters string
        let paramsRange = Range(match.range(at: 2), in: response) ?? typeRange
        let paramsString = String(response[paramsRange])

        // Parse key="value" pairs
        let params = parseParams(paramsString)

        // Build the action based on type
        let action: BuddyAction?
        switch typeString {
        case "ADD_HABIT":
            action = parseAddHabit(params: params)
        case "UPDATE_HABIT":
            action = parseUpdateHabit(params: params, habits: habits)
        case "DELETE_HABIT":
            action = parseDeleteHabit(params: params, habits: habits)
        default:
            action = nil
        }

        // Remove the marker from the response
        let fullMatchRange = Range(match.range, in: response)!
        var cleanedText = response
        cleanedText.removeSubrange(fullMatchRange)
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParseResult(cleanedText: cleanedText, action: action)
    }

    /// Parses key="value" pairs from a parameter string.
    private static func parseParams(_ paramsString: String) -> [String: String] {
        var params: [String: String] = [:]
        let pattern = #"(\w+)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return params
        }

        let matches = regex.matches(in: paramsString, range: NSRange(paramsString.startIndex..., in: paramsString))
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: paramsString),
               let valueRange = Range(match.range(at: 2), in: paramsString) {
                let key = String(paramsString[keyRange])
                let value = String(paramsString[valueRange])
                params[key] = value
            }
        }
        return params
    }

    private static func parseAddHabit(params: [String: String]) -> BuddyAction? {
        guard let name = params["name"], !name.isEmpty else { return nil }
        let goal = params["goal"] ?? "Daily"
        let color = params["color"]

        return BuddyAction(
            type: .addHabit,
            habitName: name,
            habitGoal: goal,
            habitColor: color,
            displayText: "Add habit: \(name) (\(goal))"
        )
    }

    private static func parseUpdateHabit(params: [String: String], habits: [Habit]) -> BuddyAction? {
        guard let name = params["name"], !name.isEmpty else { return nil }

        // Find matching habit by name (case-insensitive)
        let targetHabit = habits.first { $0.name.lowercased() == name.lowercased() }

        let newGoal = params["newGoal"]
        let newColor = params["newColor"]

        var displayParts: [String] = []
        if let goal = newGoal { displayParts.append("goal to \"\(goal)\"") }
        if newColor != nil { displayParts.append("color") }
        let changes = displayParts.isEmpty ? "settings" : displayParts.joined(separator: " and ")

        return BuddyAction(
            type: .updateHabit,
            habitName: name,
            habitGoal: newGoal,
            habitColor: newColor,
            targetHabitID: targetHabit?.id,
            displayText: "Update \(name): change \(changes)"
        )
    }

    private static func parseDeleteHabit(params: [String: String], habits: [Habit]) -> BuddyAction? {
        guard let name = params["name"], !name.isEmpty else { return nil }

        // Find matching habit by name (case-insensitive)
        let targetHabit = habits.first { $0.name.lowercased() == name.lowercased() }

        return BuddyAction(
            type: .deleteHabit,
            habitName: name,
            targetHabitID: targetHabit?.id,
            displayText: "Delete habit: \(name)"
        )
    }
}
