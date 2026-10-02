//
//  BuddyAction.swift
//  Track21
//
//  Models for AI buddy habit management actions. The buddy embeds action
//  markers in its responses, which are parsed into these structures and
//  presented to the user for confirmation before execution.
//

import Foundation

/// The type of habit management action the buddy can perform.
enum BuddyActionType: String, Codable {
    case addHabit
    case updateHabit
    case deleteHabit
}

/// The status of a pending action attached to a chat message.
enum ActionStatus: String, Codable {
    case pending     // Awaiting user confirmation
    case confirmed   // User tapped Confirm
    case cancelled   // User tapped Cancel
    case executed    // Action completed successfully
    case failed      // Action execution failed
}

/// A habit management action extracted from an AI buddy response.
struct BuddyAction: Identifiable, Equatable, Codable {
    let id: UUID
    let type: BuddyActionType
    let habitName: String
    let habitGoal: String?
    let habitColor: String?
    let targetHabitID: UUID?  // For update/delete — resolved at parse time
    let displayText: String   // Human-readable summary for the UI

    init(
        id: UUID = UUID(),
        type: BuddyActionType,
        habitName: String,
        habitGoal: String? = nil,
        habitColor: String? = nil,
        targetHabitID: UUID? = nil,
        displayText: String
    ) {
        self.id = id
        self.type = type
        self.habitName = habitName
        self.habitGoal = habitGoal
        self.habitColor = habitColor
        self.targetHabitID = targetHabitID
        self.displayText = displayText
    }
}
