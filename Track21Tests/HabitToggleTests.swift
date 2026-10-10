//
//  HabitToggleTests.swift
//  Track21Tests
//
//  Regression suite for habit tick/untick and sync-merge races.
//  Pure logic only — no UserDefaults / Supabase — so Swift Testing can
//  run these in parallel without flaking on shared storage.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

@MainActor
struct HabitToggleTests {

    private let calendar = Calendar.current

    private func day(_ offset: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: reference))!
    }

    private func makeHabit(
        name: String,
        id: UUID = UUID(),
        startOffset: Int = 0,
        completed: [Int] = [],
        syncStatus: SyncStatus = .pending
    ) -> Habit {
        let h = Habit(
            id: id,
            name: name,
            goal: "test",
            color: "A78BFA",
            startDate: day(-startOffset),
            completedDates: completed.map { day(-$0) },
            syncStatus: syncStatus
        )
        return h
    }

    // MARK: - Distinct identities / wrong-row toggle

    @Test func habitsHaveDistinctStableIds() {
        let a = makeHabit(name: "Water")
        let b = makeHabit(name: "Read")
        #expect(a.id != b.id)
        #expect(a.id == a.id)
    }

    @Test func toggleHabitADoesNotChangeHabitB() {
        let a = makeHabit(name: "Water")
        let b = makeHabit(name: "Read")
        let today = day(0)

        HabitCompletionSyncLogic.toggleCompletion(in: [a, b], matching: a, on: today)

        #expect(a.isCompleted(on: today) == true)
        #expect(b.isCompleted(on: today) == false)
        #expect(b.completedDates.isEmpty)
    }

    @Test func toggleUsesLiveInstanceMatchingIdNotStaleCopy() {
        let liveA = makeHabit(name: "Water")
        let liveB = makeHabit(name: "Read")
        // Stale ForEach-style copy: same id as A, but a different object.
        let staleA = Habit(
            id: liveA.id,
            name: liveA.name,
            goal: liveA.goal,
            color: liveA.color,
            startDate: liveA.startDate,
            completedDates: []
        )

        HabitCompletionSyncLogic.toggleCompletion(in: [liveA, liveB], matching: staleA, on: day(0))

        #expect(liveA.isCompletedToday() == true)
        #expect(staleA.isCompletedToday() == false) // stale copy untouched
        #expect(liveB.isCompletedToday() == false)
    }

    @Test func toggleUnknownIdIsNoOp() {
        let a = makeHabit(name: "Water")
        let ghost = makeHabit(name: "Ghost")

        let result = HabitCompletionSyncLogic.toggleCompletion(
            in: [a],
            matching: ghost,
            on: day(0)
        )

        #expect(result == nil)
        #expect(a.isCompletedToday() == false)
    }

    // MARK: - Untick restores

    @Test func untickAfterTickRestoresIncomplete() {
        let habit = makeHabit(name: "Water")
        let today = day(0)

        HabitCompletionSyncLogic.toggleCompletion(in: [habit], matching: habit, on: today)
        #expect(habit.isCompleted(on: today) == true)
        #expect(habit.syncStatus == .pending)

        HabitCompletionSyncLogic.toggleCompletion(in: [habit], matching: habit, on: today)
        #expect(habit.isCompleted(on: today) == false)
        #expect(habit.completedDates.isEmpty)
        #expect(habit.syncStatus == .pending)
    }

    @Test func toggleCompletionRemovesDuplicateDayEntries() {
        let habit = makeHabit(name: "Water")
        let today = day(0)
        // Simulate sync/ISO round-trip duplicates for the same calendar day.
        habit.completedDates = [today, today.addingTimeInterval(3600), today]

        habit.toggleCompletion(for: today)

        #expect(habit.isCompleted(on: today) == false)
        #expect(habit.completedDates.filter { calendar.isDate($0, inSameDayAs: today) }.isEmpty)
    }

    @Test func archivedHabitCannotBeToggled() {
        // 21 completed days → finished cycle → isInActiveCycle == false
        let offsets = Array(0..<21)
        let habit = makeHabit(name: "Done", startOffset: 20, completed: offsets)
        #expect(habit.isInActiveCycle == false)

        let result = HabitCompletionSyncLogic.toggleCompletion(
            in: [habit],
            matching: habit,
            on: day(0)
        )

        #expect(result == nil)
        #expect(habit.completedDates.count == 21)
    }

    // MARK: - Calendar green uses active habits only

    @Test func fullyCompleteIgnoresArchivedHabits() {
        let active = makeHabit(name: "Water", startOffset: 2)
        active.completedDates = [day(0)]

        // Window closed (started 30 days ago) → archived regardless of ticks.
        // Not completed "today", so a buggy all-habits check would stay ungreen.
        let archived = makeHabit(name: "Old", startOffset: 30, completed: Array(10..<30))
        #expect(archived.isInActiveCycle == false)
        #expect(archived.isCompleted(on: day(0)) == false)

        let all = [active, archived]
        let activeOnly = all.filter(\.isInActiveCycle)

        #expect(activeOnly.map(\.name) == ["Water"])
        #expect(HabitCompletionSyncLogic.isFullyComplete(activeHabits: activeOnly, on: day(0)) == true)
        // Bug regression: counting *all* habits (including archived) blocks green.
        #expect(HabitCompletionSyncLogic.isFullyComplete(activeHabits: all, on: day(0)) == false)
    }

    @Test func fullyCompleteRequiresEveryActiveHabit() {
        let water = makeHabit(name: "Water")
        let read = makeHabit(name: "Read")
        water.completedDates = [day(0)]

        #expect(HabitCompletionSyncLogic.isFullyComplete(activeHabits: [water, read], on: day(0)) == false)

        read.completedDates = [day(0)]
        #expect(HabitCompletionSyncLogic.isFullyComplete(activeHabits: [water, read], on: day(0)) == true)
    }

    @Test func fullyCompleteIsFalseWhenNoActiveHabits() {
        #expect(HabitCompletionSyncLogic.isFullyComplete(activeHabits: [], on: day(0)) == false)
    }

    // MARK: - Merge preserves local instances + completions

    @Test func mergeHabitListsKeepsLocalInstanceIdentity() {
        let local = makeHabit(name: "Water", completed: [0])
        let remoteClone = Habit(
            id: local.id,
            name: "Water Renamed",
            goal: "new goal",
            color: "FF0000",
            startDate: local.startDate,
            completedDates: [], // remote lagging
            syncStatus: .synced,
            updatedAt: Date().addingTimeInterval(60)
        )
        // Local is pending (user just ticked) — metadata must NOT be overwritten
        // and instance must stay the same object.
        local.syncStatus = .pending

        let merged = HabitCompletionSyncLogic.mergeHabitLists(local: [local], remote: [remoteClone])

        #expect(merged.count == 1)
        #expect(ObjectIdentifier(merged[0]) == ObjectIdentifier(local))
        #expect(merged[0].isCompleted(on: day(0)) == true)
        #expect(merged[0].name == "Water") // pending → keep local metadata
    }

    @Test func mergeHabitListsAppendsRemoteOnlyHabits() {
        let local = makeHabit(name: "Water")
        let remoteOnly = makeHabit(name: "Cloud")

        let merged = HabitCompletionSyncLogic.mergeHabitLists(
            local: [local],
            remote: [remoteOnly]
        )

        #expect(merged.map(\.id) == [local.id, remoteOnly.id])
    }

    // MARK: - applyCompletedSync / mid-sync races

    @Test func applyKeepsLocalCompletionsWhenRemoteLags() {
        let live = makeHabit(name: "Water", syncStatus: .pending)
        live.completedDates = [day(0)]
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [live])

        // Synced snapshot still empty (remote lag / old upload).
        let synced = Habit(
            id: live.id,
            name: live.name,
            goal: live.goal,
            color: live.color,
            startDate: live.startDate,
            completedDates: [],
            syncStatus: .synced
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: [live],
            syncedHabits: [synced],
            fingerprintsAtStart: startPrint
        )

        #expect(result.habits.count == 1)
        #expect(ObjectIdentifier(result.habits[0]) == ObjectIdentifier(live))
        #expect(live.isCompleted(on: day(0)) == true)
        #expect(live.syncStatus == .pending)
        #expect(result.needsFollowUp == true)
    }

    @Test func applyPreservesMidFlightUntick() {
        let live = makeHabit(name: "Water")
        live.completedDates = [day(0)]
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [live])

        // User unticked while sync was in flight.
        live.toggleCompletion(for: day(0))
        #expect(live.isCompleted(on: day(0)) == false)

        // Synced payload still has the old green day.
        let synced = Habit(
            id: live.id,
            name: live.name,
            goal: live.goal,
            color: live.color,
            startDate: live.startDate,
            completedDates: [day(0)],
            syncStatus: .synced
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: [live],
            syncedHabits: [synced],
            fingerprintsAtStart: startPrint
        )

        #expect(live.isCompleted(on: day(0)) == false)
        #expect(live.syncStatus == .pending)
        #expect(result.needsFollowUp == true)
    }

    @Test func applyMarksPendingWhenToggleMatchesSyncedButChangedSinceStart() {
        // Kickoff: incomplete. Mid-flight: user ticks. Sync returns the tick
        // (live == synced) but fingerprint != start → still needs follow-up
        // so we don't mark .synced and drop a later undo.
        let live = makeHabit(name: "Water", syncStatus: .pending)
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [live])

        live.toggleCompletion(for: day(0))

        let synced = Habit(
            id: live.id,
            name: live.name,
            goal: live.goal,
            color: live.color,
            startDate: live.startDate,
            completedDates: [day(0)],
            syncStatus: .synced
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: [live],
            syncedHabits: [synced],
            fingerprintsAtStart: startPrint
        )

        #expect(live.isCompleted(on: day(0)) == true)
        #expect(live.syncStatus == .pending)
        #expect(result.needsFollowUp == true)
    }

    @Test func applyMarksSyncedWhenUnchangedThroughFlight() {
        let live = makeHabit(name: "Water", completed: [0], syncStatus: .pending)
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [live])

        let synced = Habit(
            id: live.id,
            name: "Water",
            goal: "test",
            color: "A78BFA",
            startDate: live.startDate,
            completedDates: [day(0)],
            userId: UUID(),
            syncStatus: .synced,
            updatedAt: Date()
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: [live],
            syncedHabits: [synced],
            fingerprintsAtStart: startPrint
        )

        #expect(live.syncStatus == .synced)
        #expect(live.userId == synced.userId)
        #expect(result.needsFollowUp == false)
    }

    @Test func applyKeepsHabitsAddedMidFlight() {
        let existing = makeHabit(name: "Water", completed: [0])
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [existing])

        let seeded = makeHabit(name: "Debug Seed")
        let live = [existing, seeded]

        let syncedExisting = Habit(
            id: existing.id,
            name: existing.name,
            goal: existing.goal,
            color: existing.color,
            startDate: existing.startDate,
            completedDates: [day(0)],
            syncStatus: .synced
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: live,
            syncedHabits: [syncedExisting],
            fingerprintsAtStart: startPrint
        )

        #expect(result.habits.map(\.id).contains(seeded.id))
        #expect(result.habits.count == 2)
        #expect(result.needsFollowUp == true)
    }

    @Test func applyDoesNotSwapSiblingCompletions() {
        let water = makeHabit(name: "Water")
        let read = makeHabit(name: "Read")
        water.completedDates = [day(0)]
        // read left incomplete
        let startPrint = HabitCompletionSyncLogic.fingerprints(for: [water, read])

        // Synced snapshot wrongly has read complete and water empty (identity bug stand-in).
        let syncedWater = Habit(
            id: water.id, name: "Water", goal: "test", color: "A78BFA",
            startDate: water.startDate, completedDates: [], syncStatus: .synced
        )
        let syncedRead = Habit(
            id: read.id, name: "Read", goal: "test", color: "A78BFA",
            startDate: read.startDate, completedDates: [day(0)], syncStatus: .synced
        )

        let result = HabitCompletionSyncLogic.applyCompletedSync(
            liveHabits: [water, read],
            syncedHabits: [syncedWater, syncedRead],
            fingerprintsAtStart: startPrint
        )

        #expect(water.isCompleted(on: day(0)) == true)
        #expect(read.isCompleted(on: day(0)) == false)
        #expect(result.habits.map(\.id) == [water.id, read.id])
        #expect(water.syncStatus == .pending)
        #expect(read.syncStatus == .pending)
        #expect(result.needsFollowUp == true)
    }

    /// Deferred sync must not go through applyCompletedSync — pending stays pending.
    @Test func deferredSyncPathLeavesPendingUntouched() {
        let habit = makeHabit(name: "Water", completed: [0], syncStatus: .pending)
        // Simulate SyncOutcome.deferred: ViewModel returns without applying.
        let wasDeferred = true
        if HabitCompletionSyncLogic.shouldRetryPendingAfterSync(wasDeferred: wasDeferred) {
            _ = HabitCompletionSyncLogic.applyCompletedSync(
                liveHabits: [habit],
                syncedHabits: [],
                fingerprintsAtStart: [:]
            )
        }
        #expect(habit.syncStatus == .pending)
        #expect(habit.isCompleted(on: day(0)) == true)
    }

    /// Regression for the untick freeze: deferred must NOT clear-and-retry
    /// pending. `.deferred` returns without `await`, so retrying spins the
    /// MainActor until the phone hangs (tick sync in flight + quick untick).
    @Test func deferredMustNotRetryPendingInTightLoop() {
        #expect(HabitCompletionSyncLogic.shouldRetryPendingAfterSync(wasDeferred: true) == false)
        #expect(HabitCompletionSyncLogic.shouldRetryPendingAfterSync(wasDeferred: false) == true)

        var pendingUserId: UUID? = UUID()
        var reentryCount = 0
        let tripwire = 50

        func simulateCallerAfterOutcome(wasDeferred: Bool) {
            // Mirrors HabitViewModel.syncWithCloud drain policy.
            guard HabitCompletionSyncLogic.shouldRetryPendingAfterSync(wasDeferred: wasDeferred) else {
                return // leave pending for in-flight owner
            }
            if pendingUserId != nil {
                pendingUserId = nil
                reentryCount += 1
                if reentryCount >= tripwire { return }
                // Would re-enter syncWithCloud; if still busy → deferred again.
                simulateCallerAfterOutcome(wasDeferred: true)
            }
        }

        // Untick while tick sync is in flight → deferred.
        simulateCallerAfterOutcome(wasDeferred: true)

        #expect(reentryCount == 0)
        #expect(pendingUserId != nil) // still queued for the in-flight owner
    }

    @Test func completedSyncMayDrainPendingFollowUp() {
        var pendingUserId: UUID? = UUID()
        var drained = false

        if HabitCompletionSyncLogic.shouldRetryPendingAfterSync(wasDeferred: false),
           pendingUserId != nil {
            pendingUserId = nil
            drained = true
        }

        #expect(drained == true)
        #expect(pendingUserId == nil)
    }
}
