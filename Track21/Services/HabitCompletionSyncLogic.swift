//
//  HabitCompletionSyncLogic.swift
//  Track21
//
//  Pure helpers for habit tick/untick and post-sync merge.
//  Kept free of UserDefaults / Supabase so unit tests can pin the
//  regressions that used to wipe completions or toggle the wrong row.
//

import Foundation

enum HabitCompletionSyncLogic {

    // MARK: - Fingerprint

    /// Stable string of a habit's completed days (start-of-day timestamps).
    /// Used to detect mid-flight toggles during sync.
    static func completionFingerprint(_ habit: Habit) -> String {
        let calendar = Calendar.current
        return habit.completedDates
            .map { String(calendar.startOfDay(for: $0).timeIntervalSince1970) }
            .sorted()
            .joined(separator: ",")
    }

    static func fingerprints(for habits: [Habit]) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: habits.map { ($0.id, completionFingerprint($0)) })
    }

    // MARK: - Toggle (resolve by stable id)

    /// Toggle completion on the live habit matching `habit.id`.
    /// Ignores archived cycles and unknown ids. Mutates the live instance
    /// in `habits` so a stale ForEach reference cannot flip a different row.
    @discardableResult
    static func toggleCompletion(
        in habits: [Habit],
        matching habit: Habit,
        on date: Date
    ) -> Habit? {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return nil }
        let target = habits[index]
        guard target.isInActiveCycle else { return nil }
        target.toggleCompletion(for: date)
        return target
    }

    // MARK: - Calendar day green

    /// Day is fully complete only when every *active-cycle* habit is done.
    /// Archived / finished cycles must not block (or inflate) the green check.
    static func isFullyComplete(activeHabits: [Habit], on date: Date) -> Bool {
        guard !activeHabits.isEmpty else { return false }
        return activeHabits.allSatisfy { $0.isCompleted(on: date) }
    }

    // MARK: - Merge local + remote habit lists

    /// Keep local `Habit` *instances* when ids overlap. Replacing with a
    /// remote clone used to desync the UI from syncCompletedDates mutations.
    static func mergeHabitLists(local: [Habit], remote: [Habit]) -> [Habit] {
        let remoteById: [UUID: Habit] = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })

        var ordered: [Habit] = []
        var seen = Set<UUID>()
        for localHabit in local {
            seen.insert(localHabit.id)
            if let remoteHabit = remoteById[localHabit.id] {
                if localHabit.syncStatus != .pending,
                   (remoteHabit.updatedAt ?? Date.distantPast) > (localHabit.updatedAt ?? Date.distantPast) {
                    localHabit.name = remoteHabit.name
                    localHabit.goal = remoteHabit.goal
                    localHabit.color = remoteHabit.color
                    localHabit.startDate = remoteHabit.startDate
                    localHabit.userId = remoteHabit.userId ?? localHabit.userId
                    localHabit.updatedAt = remoteHabit.updatedAt
                }
            }
            ordered.append(localHabit)
        }

        let leftovers = remoteById.values
            .filter { !seen.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        ordered.append(contentsOf: leftovers)
        return ordered
    }

    // MARK: - Apply completed sync onto live habits

    struct ApplyResult {
        var habits: [Habit]
        var needsFollowUp: Bool
    }

    /// Fold a `.completed` sync snapshot back onto the live array.
    /// - Local completions win when they diverge from synced.
    /// - Mid-flight toggles (fingerprint changed since kickoff) stay pending.
    /// - Habits added while sync was in flight are kept (not wiped).
    static func applyCompletedSync(
        liveHabits: [Habit],
        syncedHabits: [Habit],
        fingerprintsAtStart: [UUID: String]
    ) -> ApplyResult {
        let liveById = Dictionary(uniqueKeysWithValues: liveHabits.map { ($0.id, $0) })
        var needsFollowUp = false
        var merged: [Habit] = []
        var seen = Set<UUID>()

        for synced in syncedHabits {
            seen.insert(synced.id)
            if let live = liveById[synced.id] {
                let startPrint = fingerprintsAtStart[synced.id] ?? ""
                let livePrint = completionFingerprint(live)
                let syncedPrint = completionFingerprint(synced)

                if livePrint != syncedPrint {
                    // Keep live.completedDates as-is (already correct).
                    live.syncStatus = .pending
                    needsFollowUp = true
                } else if livePrint != startPrint {
                    live.syncStatus = .pending
                    needsFollowUp = true
                } else {
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

        for live in liveHabits where !seen.contains(live.id) {
            merged.append(live)
            needsFollowUp = true
        }

        return ApplyResult(habits: merged, needsFollowUp: needsFollowUp)
    }

    // MARK: - Post-sync drain policy

    /// Whether the ViewModel may clear `pendingSyncUserId` and re-enter
    /// `syncWithCloud` after this outcome.
    ///
    /// **Must be false for deferred.** `SyncService.syncHabits` returns
    /// `.deferred` synchronously (no `await`) when another sync is already
    /// in flight. Recursing on deferred therefore busy-loops the MainActor
    /// and freezes the UI — the classic "untick right after tick" hang,
    /// because the tick's sync is still running when untick queues another.
    /// The in-flight sync owns draining `pendingSyncUserId` when it finishes.
    static func shouldRetryPendingAfterSync(wasDeferred: Bool) -> Bool {
        !wasDeferred
    }

}
