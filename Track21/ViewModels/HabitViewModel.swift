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

    /// Set whenever a habit toggle or streak-freeze protection just crossed
    /// a badge into unlocked — ContentView observes this to show a
    /// celebration toast, then clears it back to empty.
    var recentlyUnlockedAchievements: [Achievement] = []

    /// Set the moment a habit finishes its full 21-day cycle for the first
    /// time — ContentView presents HabitVictoryView full-screen for this,
    /// then clears it back to nil. See HabitVictoryLogic/HabitVictoryService.
    var recentHabitVictory: Habit?

    /// Bumped on every completion toggle so summary calendar / progress
    /// UI that only tracks the `habits` array identity still redraws.
    var completionRevision: Int = 0

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
        // Always resolve by id against the live array so a stale ForEach
        // reference (e.g. after sync replaced objects) cannot toggle the
        // wrong habit — or silently no-op while the UI looks wrong.
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let target = habits[index]
        let day = Calendar.current.startOfDay(for: date)
        let before = target.isCompleted(on: day)
        target.toggleCompletion(for: date)
        let after = target.isCompleted(on: day)
        // Touch the array so @Observable subscribers that only track `habits`
        // (not nested Habit.completedDates) still refresh section membership.
        habits = Array(habits)
        completionRevision += 1
        // Match DayProgressCard: every listed habit counts, not just the 21-day window.
        let shown = habits
        let fully = !shown.isEmpty && shown.allSatisfy { $0.isCompleted(on: day) }
        print("[Track21][toggle] \(target.name) \(before)->\(after) day=\(day) shown=\(shown.count) fullyComplete=\(fully) rev=\(completionRevision)")
        saveHabits()
        checkForNewAchievements()
        checkForHabitVictory(target)

        // Trigger sync if user is logged in
        if let userId = target.userId {
            Task {
                await syncWithCloud(userId: userId)
            }
        }
    }

    /// Checks whether this habit just finished its 21-day cycle for the
    /// first time and, if so, stashes it for ContentView to celebrate.
    /// Safe to call often — no-ops once a habit has already been celebrated.
    @discardableResult
    func checkForHabitVictory(_ habit: Habit) -> Habit? {
        guard HabitVictoryService.shared.checkForNewVictory(habit) else { return nil }
        recentHabitVictory = habit
        return habit
    }

    /// Recomputes badge state and stashes any newly-unlocked ones for
    /// ContentView to celebrate. Safe to call often — no-ops when nothing
    /// new crossed into unlocked.
    @discardableResult
    func checkForNewAchievements() -> [Achievement] {
        let newly = AchievementService.shared.refresh(habits: habits).newlyUnlocked
        if !newly.isEmpty {
            recentlyUnlockedAchievements = newly
        }
        return newly
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
            NotificationService.shared.scheduleReminder(for: habit)
        }
    }
    
    private static func completionFingerprint(_ habit: Habit) -> String {
        let calendar = Calendar.current
        let days = habit.completedDates
            .map { String(calendar.startOfDay(for: $0).timeIntervalSince1970) }
            .sorted()
            .joined(separator: ",")
        return days
    }

    func syncWithCloud(userId: UUID) async {
        // Snapshot completions at kickoff so we can detect toggles that land
        // while this sync is in flight (e.g. undo after the day went green).
        let fingerprintsAtStart = Dictionary(uniqueKeysWithValues: habits.map {
            ($0.id, Self.completionFingerprint($0))
        })
        do {
            let outcome = try await syncService.syncHabits(habits: habits, userId: userId)
            switch outcome {
            case .deferred:
                // Another sync is in flight. Leave syncStatus alone so
                // pending completions are still uploaded on the follow-up.
                break
            case .completed(let syncedHabits):
                // Always keep the live in-memory instances the UI is bound to.
                // Sync used to return remote clones; assigning those back could
                // resurrect a just-undone day even after fingerprint mend.
                let liveById = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
                var needsFollowUp = false
                var merged: [Habit] = []
                for synced in syncedHabits {
                    if let live = liveById[synced.id] {
                        let startPrint = fingerprintsAtStart[synced.id] ?? ""
                        let livePrint = Self.completionFingerprint(live)
                        let syncedPrint = Self.completionFingerprint(synced)
                        // Local completions always win for days the user touched.
                        if livePrint != syncedPrint {
                            // Keep live.completedDates as-is (already correct).
                            live.syncStatus = .pending
                            needsFollowUp = true
                            print("[Track21][sync] keep-live \(live.name) live!=synced followUp")
                        } else if livePrint != startPrint {
                            live.syncStatus = .pending
                            needsFollowUp = true
                            print("[Track21][sync] mid-sync toggle \(live.name) followUp")
                        } else {
                            // Carry any non-completion fields sync may have refreshed.
                            live.name = synced.name
                            live.goal = synced.goal
                            live.color = synced.color
                            live.startDate = synced.startDate
                            live.userId = synced.userId ?? live.userId
                            live.updatedAt = synced.updatedAt
                            live.syncStatus = .synced
                        }
                        merged.append(live)
                    } else {
                        synced.syncStatus = .synced
                        merged.append(synced)
                    }
                }
                habits = merged
                completionRevision += 1
                print("[Track21][sync] applied rev=\(completionRevision) habits=\(habits.count) followUp=\(needsFollowUp)")
                saveHabits()
                if needsFollowUp {
                    syncService.pendingSyncUserId = userId
                }
            }

            // If another sync was queued while we were syncing, run it now
            // against the live habits array (not a deferred snapshot).
            if let pendingUserId = syncService.pendingSyncUserId {
                syncService.pendingSyncUserId = nil
                await syncWithCloud(userId: pendingUserId)
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
            checkForNewAchievements()
            protected.forEach { checkForHabitVictory($0) }
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
        recentlyUnlockedAchievements = []
        recentHabitVictory = nil
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        AchievementService.shared.clearData()
        HabitVictoryService.shared.clearData()
        JournalService.shared.clearData()
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
