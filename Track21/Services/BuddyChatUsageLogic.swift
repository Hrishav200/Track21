//
//  BuddyChatUsageLogic.swift
//  Track21
//
//  Pure decision logic for the free tier's daily Buddy chat cap. The limit
//  isn't a cost-control measure — the model runs entirely on-device, so a
//  message costs nothing marginally — it exists purely as a Pro upgrade
//  incentive.
//

import Foundation

enum BuddyChatUsageLogic {
    static let freeDailyMessageLimit = 5

    static func canSendMessage(sentToday: Int, isPremium: Bool) -> Bool {
        isPremium || sentToday < freeDailyMessageLimit
    }

    /// `nil` means unlimited (premium).
    static func remainingMessages(sentToday: Int, isPremium: Bool) -> Int? {
        guard !isPremium else { return nil }
        return max(0, freeDailyMessageLimit - sentToday)
    }
}
