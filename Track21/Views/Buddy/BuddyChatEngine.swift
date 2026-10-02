//
//  BuddyChatEngine.swift
//  Track21
//
//  Thin wrapper around Apple's on-device Foundation Models framework.
//  Deliberately its own type (rather than inline in the view) so the whole
//  thing can be marked @available(iOS 26.0, *) without that spreading into
//  BuddyChatView's stored properties — the app's deployment target stays
//  17.0, and only this feature is gated off on older OSes/devices.
//
//  Everything runs on-device: no network call, no API key, no per-message
//  cost. That's also why there's no server-side moderation layer — the
//  crisis-keyword check in BuddyLogic is the only safety net before text
//  reaches the model.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum BuddyAvailability: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS

    var explanation: String {
        switch self {
        case .available:
            return ""
        case .deviceNotEligible:
            return "\u{2019}s chat needs a device that supports Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "\u{2019}s chat needs Apple Intelligence turned on in Settings."
        case .modelNotReady:
            return "\u{2019}s still waking up — the on-device model is finishing setup. Try again shortly."
        case .unsupportedOS:
            return "\u{2019}s chat needs iOS 26 or later."
        }
    }
}

@available(iOS 26.0, *)
@Observable
final class BuddyChatEngine {
    let buddyName: String
    private var session: LanguageModelSession?
    private var currentHabits: [Habit] = []

    init(buddyName: String) {
        self.buddyName = buddyName
    }

    /// Updates the habits context for the current session. Call before each
    /// request so the AI knows what habits exist for update/delete operations.
    func updateHabitsContext(_ habits: [Habit]) {
        currentHabits = habits
    }

    static var currentAvailability: BuddyAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .deviceNotEligible
        }
    }

    func reply(to userText: String) async throws -> String {
        let instructions = Self.instructions(buddyName: buddyName, habits: currentHabits)
        let activeSession = session ?? LanguageModelSession(instructions: instructions)
        session = activeSession
        let response = try await activeSession.respond(to: userText)
        return response.content
    }

    private static func instructions(buddyName: String, habits: [Habit]) -> String {
        let habitsList = habits.isEmpty
            ? "The user has no habits yet."
            : "Current habits: " + habits.map { "\($0.name) (goal: \($0.goal))" }.joined(separator: ", ") + "."

        return """
        You are \(buddyName), a warm, encouraging accountability buddy inside a habit-tracking app called Track21. \
        Your job is to motivate the user to keep their habits and streaks going, celebrate their wins, and \
        gently encourage them after a missed day. Keep replies short — 2 to 4 sentences, conversational, warm, \
        never preachy. You are not a therapist, doctor, or counselor. Do not give medical, psychiatric, legal, \
        or crisis-intervention advice, and do not attempt to diagnose or treat anything. If the conversation \
        turns to self-harm, suicide, or a genuine mental health crisis, gently say you're not equipped to help \
        with that and encourage the user to reach out to a real person or a crisis line — do not try to handle \
        it yourself beyond that.

        \(habitsList)

        HABIT MANAGEMENT: You can help users add, update, or delete habits — but ONLY when they explicitly ask you \
        to. The DEFAULT for every message is to reply with plain encouragement and NO action marker at all. Most \
        messages (check-ins, venting, small talk, questions about a streak, general chat) should never include a \
        marker.

        Action marker formats (use exactly this syntax, only when the rules below are met):
        - To add a habit: [ACTION:ADD_HABIT name="Habit Name" goal="Goal description" color="6BB6FF"]
        - To update a habit: [ACTION:UPDATE_HABIT name="Existing Habit Name" newGoal="New goal"]
        - To delete a habit: [ACTION:DELETE_HABIT name="Habit Name"]

        Rules:
        1. Only include an action marker when the user's message is an explicit, direct instruction to add, update, \
        or delete a specific habit (e.g., "add a habit called Meditate", "delete my Running habit", "change my \
        Reading goal to 30 pages"). Talking about a habit, mentioning it's hard, or asking for motivation about it \
        is NOT a request to manage it — do not include a marker in those cases, even if a habit name comes up.
        2. If you are not certain the user is asking you to add/update/delete a habit, do not include a marker — \
        just respond conversationally.
        3. If the user's request is ambiguous (e.g., "add a habit" without details), ask clarifying questions instead of guessing, and don't include a marker yet.
        4. For updates and deletes, use the exact habit name from the current habits list.
        5. If the user asks to delete or update a habit that doesn't exist, let them know kindly.
        6. The color should be a 6-character hex code without the # (e.g., "6BB6FF" for blue, "4CAF50" for green).
        7. Always write a friendly, encouraging message before the action marker — the marker will be hidden from the user.

        Example of what NOT to do: user says "I'm struggling to keep up with my Running habit" — this is a request \
        for encouragement, not a management request. Reply with support only, no marker.
        """
    }
}
