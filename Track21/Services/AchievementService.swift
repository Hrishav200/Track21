//
//  AchievementService.swift
//  Track21
//
//  Achievements themselves are always recomputed fresh from habits/chat
//  activity (see AchievementLogic) — the only thing persisted here is the
//  moment each badge first crossed into unlocked, so the UI can show an
//  earned date and so a badge's celebration only fires once.
//

import Foundation

@Observable
final class AchievementService {
    static let shared = AchievementService()

    private let unlockedDatesKey = "Track21AchievementUnlockedDates"
    private(set) var unlockedDates: [String: Date] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: unlockedDatesKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            unlockedDates = decoded
        }
    }

    /// Recomputes every badge's current state and returns it alongside
    /// whichever badges just crossed into unlocked for the first time
    /// (empty if none did) — the caller uses that list to show a
    /// celebration toast.
    @discardableResult
    func refresh(habits: [Habit], today: Date = Date()) -> (all: [Achievement], newlyUnlocked: [Achievement]) {
        var evaluated = AchievementLogic.evaluate(habits: habits, chatDayCount: BuddyService.shared.chatDayCount, today: today)
        var newlyUnlocked: [Achievement] = []

        for index in evaluated.indices where evaluated[index].isUnlocked {
            if let existingDate = unlockedDates[evaluated[index].id] {
                evaluated[index].unlockedDate = existingDate
            } else {
                unlockedDates[evaluated[index].id] = today
                evaluated[index].unlockedDate = today
                newlyUnlocked.append(evaluated[index])
            }
        }

        if !newlyUnlocked.isEmpty { persist() }
        return (evaluated, newlyUnlocked)
    }

    func clearData() {
        unlockedDates = [:]
        UserDefaults.standard.removeObject(forKey: unlockedDatesKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(unlockedDates) {
            UserDefaults.standard.set(data, forKey: unlockedDatesKey)
        }
    }
}
