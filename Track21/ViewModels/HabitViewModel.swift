//
//  HabitViewModel.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import SwiftUI

@Observable
class HabitViewModel {
    var habits: [Habit] = []
    var userName: String = "John"
    
    private let saveKey = "Track21SavedHabits"
    private let userNameKey = "Track21UserName"
    private let syncService = SyncService()
    
    var isSyncing: Bool { syncService.isSyncing }
    var lastSyncDate: Date? { syncService.lastSyncDate }
    
    init() {
        loadHabits()
        loadUserName()
    }
    
    var todayCompletedCount: Int {
        habits.filter { $0.isCompletedToday() }.count
    }
    
    var todayTotalCount: Int {
        habits.count
    }
    
    var completedHabits: [Habit] {
        habits.filter { $0.isCompletedToday() }
    }
    
    var incompleteHabits: [Habit] {
        habits.filter { !$0.isCompletedToday() }
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        saveHabits()
    }
    
    func deleteHabit(_ habit: Habit) async {
        // Delete from cloud first
        if let userId = habit.userId {
            try? await syncService.deleteHabit(habit)
        }
        
        // Remove from local
        habits.removeAll { $0.id == habit.id }
        saveHabits()
    }
    
    func toggleHabitCompletion(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].toggleCompletion()
            saveHabits()
        }
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
        }
    }
    
    func syncWithCloud(userId: UUID) async {
        do {
            let syncedHabits = try await syncService.syncHabits(habits: habits, userId: userId)
            habits = syncedHabits.map { habit in
                var updated = habit
                updated.syncStatus = .synced
                return updated
            }
            saveHabits()
        } catch {
            print("Sync error: \(error)")
        }
    }
    
    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }
    
    private func loadUserName() {
        if let name = UserDefaults.standard.string(forKey: userNameKey) {
            userName = name
        }
    }
}
