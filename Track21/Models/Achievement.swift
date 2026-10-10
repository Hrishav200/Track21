//
//  Achievement.swift
//  Track21
//
//  Pure value type describing a single badge's unlock state. Achievements
//  themselves are never persisted — they're recomputed from habits/chat
//  activity every time. Only `unlockedDate` (the moment a badge first
//  crossed into unlocked) is persisted, by AchievementService.
//

import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let emoji: String
    let lockedDescription: String
    let unlockedDescription: String
    let progressCurrent: Int
    let progressTarget: Int
    var isUnlocked: Bool
    var unlockedDate: Date?

    var progress: Double {
        guard progressTarget > 0 else { return isUnlocked ? 1 : 0 }
        return min(Double(progressCurrent) / Double(progressTarget), 1)
    }
}
