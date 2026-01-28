//
//  SyncService.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import Supabase

@Observable
class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    
    private let supabase = SupabaseConfig.client
    
    func syncHabits(habits: [Habit], userId: UUID) async throws -> [Habit] {
        guard !isSyncing else { return habits }
        
        isSyncing = true
        syncError = nil
        
        defer { isSyncing = false }
        
        do {
            // 1. Fetch remote habits
            let remoteHabits = try await fetchRemoteHabits(userId: userId)
            
            // 2. Merge local and remote habits
            let mergedHabits = mergeHabits(local: habits, remote: remoteHabits)
            
            // 3. Upload pending changes
            try await uploadPendingChanges(habits: mergedHabits, userId: userId)
            
            // 4. Sync completed dates
            let habitsWithDates = try await syncCompletedDates(habits: mergedHabits)
            
            lastSyncDate = Date()
            return habitsWithDates
            
        } catch {
            syncError = error.localizedDescription
            throw error
        }
    }
    
    private func fetchRemoteHabits(userId: UUID) async throws -> [Habit] {
        let response: [Habit] = try await supabase
            .from("habits")
            .select()
            .eq("user_id", value: userId)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        return response
    }
    
    private func mergeHabits(local: [Habit], remote: [Habit]) -> [Habit] {
        var merged: [UUID: Habit] = [:]
        
        // Add all remote habits
        for habit in remote {
            merged[habit.id] = habit
        }
        
        // Merge local habits (local wins if updated_at is newer or pending)
        for localHabit in local {
            if let remoteHabit = merged[localHabit.id] {
                // Keep newer version
                if localHabit.syncStatus == .pending ||
                   (localHabit.updatedAt ?? Date.distantPast) > (remoteHabit.updatedAt ?? Date.distantPast) {
                    merged[localHabit.id] = localHabit
                }
            } else {
                // New local habit
                merged[localHabit.id] = localHabit
            }
        }
        
        return Array(merged.values)
    }
    
    private func uploadPendingChanges(habits: [Habit], userId: UUID) async throws {
        let pendingHabits = habits.filter { $0.syncStatus == .pending }
        
        for habit in pendingHabits {
            var habitToUpload = habit
            habitToUpload.userId = userId
            habitToUpload.updatedAt = Date()
            
            // Upsert habit
            try await supabase
                .from("habits")
                .upsert(habitToUpload)
                .execute()
        }
    }
    
    private func syncCompletedDates(habits: [Habit]) async throws -> [Habit] {
        var updatedHabits = habits
        
        for (index, habit) in habits.enumerated() {
            // Fetch remote completed dates
            let remoteDates: [CompletedDate] = try await supabase
                .from("completed_dates")
                .select()
                .eq("habit_id", value: habit.id)
                .execute()
                .value
            
            // Merge with local dates
            var allDates = Set(habit.completedDates)
            for remoteDate in remoteDates {
                allDates.insert(remoteDate.completedDate)
            }
            
            updatedHabits[index].completedDates = Array(allDates).sorted()
            
            // Upload any local dates not in remote
            for date in habit.completedDates {
                let exists = remoteDates.contains { Calendar.current.isDate($0.completedDate, inSameDayAs: date) }
                if !exists {
                    let newDate = CompletedDate(
                        id: UUID(),
                        habitId: habit.id,
                        completedDate: date,
                        createdAt: Date()
                    )
                    try await supabase
                        .from("completed_dates")
                        .insert(newDate)
                        .execute()
                }
            }
        }
        
        return updatedHabits
    }
    
    func deleteHabit(_ habit: Habit) async throws {
        try await supabase
            .from("habits")
            .update(["deleted_at": Date()])
            .eq("id", value: habit.id)
            .execute()
    }
}
