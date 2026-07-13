//
//  HabitViewModel.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class HabitViewModel {
    var habits: [Habit] = []
    var userName: String = "Friend"
    
    private let saveKey = "Track21SavedHabits"
    private let userNameKey = "Track21UserName"
    private let syncService = SyncService()
    
    var isSyncing: Bool { syncService.isSyncing }
    var lastSyncDate: Date? { syncService.lastSyncDate }
    var syncError: String? { syncService.syncError }

    var freezesAvailable: Int { StreakFreezeService.shared.freezesAvailable }
    var freezeRefillDate: Date { StreakFreezeService.shared.refillDate }
    var isPremium: Bool { StreakFreezeService.shared.isPremium }

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
        NotificationService.shared.scheduleReminder(for: habit)
    }

    func deleteHabit(_ habit: Habit) async {
        // Delete from cloud first if user is set
        if habit.userId != nil {
            do {
                try await syncService.deleteHabit(habit)
            } catch {
                // Silently handle cloud delete failure - local delete still proceeds
            }
        }

        // Remove from local
        habits.removeAll { $0.id == habit.id }
        saveHabits()
        NotificationService.shared.cancelReminder(for: habit)
    }
    
    func toggleHabitCompletion(_ habit: Habit) {
        toggleHabitCompletion(habit, for: Date())
    }

    func toggleHabitCompletion(_ habit: Habit, for date: Date) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].toggleCompletion(for: date)
            saveHabits()

            // Trigger sync if user is logged in
            if let userId = habits[index].userId {
                Task {
                    await syncWithCloud(userId: userId)
                }
            }
        }
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
            NotificationService.shared.scheduleReminder(for: habit)
        }
    }
    
    func syncWithCloud(userId: UUID) async {
        do {
            let syncedHabits = try await syncService.syncHabits(habits: habits, userId: userId)
            habits = syncedHabits.map { habit in
                let updated = habit
                updated.syncStatus = .synced
                return updated
            }
            saveHabits()

            // If another sync was queued while we were syncing, run it now
            if let pending = syncService.pendingSync {
                syncService.pendingSync = nil
                await syncWithCloud(userId: pending.userId)
            }
        } catch {
            // Sync error is exposed via syncError property
        }
    }
    
    /// Call once per app foreground. Auto-protects any habit that missed
    /// exactly yesterday while mid-streak, consuming a freeze if available.
    /// Returns the habits that got protected so the UI can show a toast.
    @discardableResult
    func protectStreaksIfNeeded() -> [Habit] {
        let protected = StreakFreezeService.shared.protectStreaks(for: habits)
        if !protected.isEmpty {
            saveHabits()
        }
        return protected
    }

    func saveUserName(_ name: String) {
        userName = name
        UserDefaults.standard.set(name, forKey: userNameKey)
    }

    func clearData() {
        habits = []
        userName = "Friend"
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
    }
    
    private func saveHabits() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode([Habit].self, from: data) {
                habits = decoded
            }
        }
    }
    
    private func loadUserName() {
        if let name = UserDefaults.standard.string(forKey: userNameKey) {
            userName = name
        }
    }
}
