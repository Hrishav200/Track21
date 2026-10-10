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
        cancelRemindersForArchivedHabits()
    }

    /// Finished cycles and deleted habits shouldn't keep firing local
    /// notifications. Reconcile against whatever is still pending, not only
    /// habits we still have a reference to.
    private func cancelRemindersForArchivedHabits() {
        NotificationService.shared.reconcilePendingReminders(habits: habits)
    }
    
    /// Habits still in an open, unfinished 21-day cycle — Home list source.
    var activeHabits: [Habit] {
        habits.filter(\.isInActiveCycle)
    }

    /// Finished or expired cycles — Trophy Case / Archive.
    var archivedHabits: [Habit] {
        habits.filter(\.isArchived)
    }

    var todayCompletedCount: Int {
        activeHabits.filter { $0.isCompletedToday() }.count
    }
    
    var todayTotalCount: Int {
        activeHabits.count
    }
    
    var completedHabits: [Habit] {
        activeHabits.filter { $0.isCompletedToday() }
    }
    
    var incompleteHabits: [Habit] {
        activeHabits.filter { !$0.isCompletedToday() }
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
        // Resolve by id + active-cycle guard via shared logic (unit-tested).
        let day = Calendar.current.startOfDay(for: date)
        let before = habits.first(where: { $0.id == habit.id })?.isCompleted(on: day) ?? false
        guard let target = HabitCompletionSyncLogic.toggleCompletion(
            in: habits,
            matching: habit,
            on: date
        ) else { return }
        let after = target.isCompleted(on: day)
        // Touch the array so @Observable subscribers that only track `habits`
        // (not nested Habit.completedDates) still refresh section membership.
        habits = Array(habits)
        completionRevision += 1
        // Match DayProgressCard: only active (non-archived) habits count today.
        let shown = activeHabits
        let fully = HabitCompletionSyncLogic.isFullyComplete(activeHabits: shown, on: day)
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
        // Cycle is done — stop local reminders; habit moves to Trophy Case.
        NotificationService.shared.cancelReminder(for: habit)
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
        // Finished cycles are read-only — ignore edit attempts.
        guard habit.isInActiveCycle else { return }
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveHabits()
            NotificationService.shared.scheduleReminder(for: habit)
        }
    }
    
    func syncWithCloud(userId: UUID, followUpDepth: Int = 0) async {
        // Hard cap so a pathological needsFollowUp loop can never pin MainActor.
        let maxFollowUps = 8
        // Snapshot completions at kickoff so we can detect toggles that land
        // while this sync is in flight (e.g. undo after the day went green).
        let fingerprintsAtStart = HabitCompletionSyncLogic.fingerprints(for: habits)
        do {
            let outcome = try await syncService.syncHabits(habits: habits, userId: userId)
            switch outcome {
            case .deferred:
                // Another sync is in flight. Do NOT drain pendingSyncUserId
                // here — syncHabits returns .deferred without suspending, so
                // recursing would busy-loop MainActor and freeze the phone
                // (common on quick untick while tick sync is still running).
                // The in-flight sync drains pending when it finishes.
                print("[Track21][sync] deferred — leaving pending for in-flight owner")
                return
            case .completed(let syncedHabits):
                let result = HabitCompletionSyncLogic.applyCompletedSync(
                    liveHabits: habits,
                    syncedHabits: syncedHabits,
                    fingerprintsAtStart: fingerprintsAtStart
                )
                habits = result.habits
                completionRevision += 1
                print("[Track21][sync] applied rev=\(completionRevision) habits=\(habits.count) followUp=\(result.needsFollowUp) depth=\(followUpDepth)")
                saveHabits()
                NotificationService.shared.reconcilePendingReminders(habits: habits)
                if result.needsFollowUp {
                    syncService.pendingSyncUserId = userId
                }
            }

            // Only reached after .completed — deferred returns above.
            // Cap follow-up depth so a pathological needsFollowUp loop
            // can never pin MainActor.
            guard followUpDepth < maxFollowUps else {
                print("[Track21][sync] follow-up depth cap hit — leaving pending")
                return
            }
            if let pendingUserId = syncService.pendingSyncUserId {
                syncService.pendingSyncUserId = nil
                await syncWithCloud(userId: pendingUserId, followUpDepth: followUpDepth + 1)
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
        let protected = StreakFreezeService.shared.protectStreaks(for: activeHabits)
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

#if DEBUG
    /// Insert or replace a habit by stable id/name. Bypasses `updateHabit`'s
    /// archived read-only guard so Debug can seed a finished Trophy Case cycle.
    func debugReplaceOrInsertHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id || $0.name == habit.name }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
        habits = Array(habits)
        completionRevision += 1
        saveHabits()
        NotificationService.shared.cancelReminder(for: habit)
        print("[Track21][debug] upsert \(habit.name) id=\(habit.id) archived=\(habit.isArchived) accounted=\(habit.cycleDaysAccounted) habits=\(habits.count)")
    }

    func debugRemoveHabit(named name: String) {
        let victims = habits.filter { $0.name == name }
        habits.removeAll { $0.name == name }
        habits = Array(habits)
        completionRevision += 1
        saveHabits()
        victims.forEach { NotificationService.shared.cancelReminder(for: $0) }
    }
#endif

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
