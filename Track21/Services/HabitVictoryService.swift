//
//  HabitVictoryService.swift
//  Track21
//
//  Tracks which habits have already had their 21-day-cycle victory screen
//  shown, so it fires exactly once per habit no matter how many times the
//  completed state gets re-evaluated (e.g. toggling a day back and forth
//  within an already-finished cycle). Mirrors AchievementService's
//  UserDefaults-backed "shown once" pattern, kept as its own small service
//  since it's a one-off celebration rather than a permanent badge record.
//

import Foundation

@Observable
final class HabitVictoryService {
    static let shared = HabitVictoryService()

    private let shownKey = "Track21VictoryShownHabitIDs"
    private(set) var shownHabitIDs: Set<UUID> = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: shownKey),
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            shownHabitIDs = decoded
        }
    }

    /// Returns true the first time a given habit crosses into a completed
    /// 21-day cycle, and false on every subsequent call for that habit —
    /// the caller uses a `true` result to trigger the celebration screen.
    @discardableResult
    func checkForNewVictory(_ habit: Habit) -> Bool {
        guard HabitVictoryLogic.hasCompletedCycle(habit), !shownHabitIDs.contains(habit.id) else {
            return false
        }
        shownHabitIDs.insert(habit.id)
        persist()
        return true
    }

    func clearData() {
        shownHabitIDs = []
        UserDefaults.standard.removeObject(forKey: shownKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(shownHabitIDs) {
            UserDefaults.standard.set(data, forKey: shownKey)
        }
    }
}
