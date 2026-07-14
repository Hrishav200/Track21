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

    init(buddyName: String) {
        self.buddyName = buddyName
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
        let activeSession = session ?? LanguageModelSession(instructions: Self.instructions(buddyName: buddyName))
        session = activeSession
        let response = try await activeSession.respond(to: userText)
        return response.content
    }

    private static func instructions(buddyName: String) -> String {
        """
        You are \(buddyName), a warm, encouraging accountability buddy inside a habit-tracking app called Track21. \
        Your job is to motivate the user to keep their habits and streaks going, celebrate their wins, and \
        gently encourage them after a missed day. Keep replies short — 2 to 4 sentences, conversational, warm, \
        never preachy. You are not a therapist, doctor, or counselor. Do not give medical, psychiatric, legal, \
        or crisis-intervention advice, and do not attempt to diagnose or treat anything. If the conversation \
        turns to self-harm, suicide, or a genuine mental health crisis, gently say you're not equipped to help \
        with that and encourage the user to reach out to a real person or a crisis line — do not try to handle \
        it yourself beyond that.
        """
    }
}
