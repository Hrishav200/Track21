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
    private var pendingSync: (habits: [Habit], userId: UUID)?

    private let supabase = SupabaseConfig.client

    func syncHabits(habits: [Habit], userId: UUID) async throws -> [Habit] {
        if isSyncing {
            // Queue this sync so it runs after the current one finishes
            pendingSync = (habits, userId)
            return habits
        }

        isSyncing = true
        syncError = nil

        defer {
            isSyncing = false
        }

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
        let response: [HabitDTO] = try await supabase
            .from("habits")
            .select()
            .eq("user_id", value: userId)
            .is("deleted_at", value: nil)
            .execute()
            .value
        
        return response.map { $0.toHabit() }
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
            // Get auth token for the request
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            let jsonBody: [String: Any] = [
                "id": habit.id.uuidString,
                "name": habit.name,
                "goal": habit.goal,
                "color": habit.color,
                "color_hex": habit.color,
                "frequency": "daily",
                "start_date": habit.startDate.ISO8601Format(),
                "user_id": userId.uuidString,
                "created_at": habit.createdAt.ISO8601Format(),
                "updated_at": Date().ISO8601Format(),
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: jsonBody)

            guard let requestURL = URL(string: "\(SupabaseConfig.url.absoluteString)/rest/v1/habits") else {
                throw NSError(domain: "SyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            if !(200..<300).contains(statusCode) {
                let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "SyncService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: responseBody])
            }
        }
    }
    
    private func syncCompletedDates(habits: [Habit]) async throws -> [Habit] {
        var updatedHabits = habits
        let calendar = Calendar.current

        for (index, habit) in habits.enumerated() {
            do {
                // Fetch remote completed dates
                let remoteDates: [CompletedDate] = try await supabase
                    .from("completed_dates")
                    .select()
                    .eq("habit_id", value: habit.id)
                    .execute()
                    .value

                let localDays = Set(habit.completedDates.map { calendar.startOfDay(for: $0) })

                // Upload local dates not in remote
                for date in localDays {
                    let existsRemotely = remoteDates.contains { calendar.isDate($0.completedDate, inSameDayAs: date) }
                    if !existsRemotely {
                        let newDate = CompletedDate(
                            id: UUID(),
                            habitId: habit.id,
                            completedDate: date,
                            createdAt: Date()
                        )
                        do {
                            try await supabase
                                .from("completed_dates")
                                .upsert(newDate)
                                .execute()
                        } catch {
                            // Continue syncing other dates even if one fails
                        }
                    }
                }

                // Delete remote dates that were removed locally (undo)
                for remoteDate in remoteDates {
                    let day = calendar.startOfDay(for: remoteDate.completedDate)
                    if !localDays.contains(day) {
                        do {
                            try await supabase
                                .from("completed_dates")
                                .delete()
                                .eq("id", value: remoteDate.id)
                                .execute()
                        } catch {
                            // Continue syncing even if one delete fails
                        }
                    }
                }

                // Local dates are the source of truth — keep them as-is
                updatedHabits[index].completedDates = Array(localDays).sorted()

            } catch {
                // Continue syncing other habits even if one fails
            }
        }

        return updatedHabits
    }
    
    func deleteHabit(_ habit: Habit) async throws {
        try await supabase
            .from("habits")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: habit.id)
            .execute()
    }
}

// MARK: - DTO for Supabase (used for network serialization)

private struct HabitDTO: Codable {
    let id: UUID
    let name: String
    let goal: String
    let colorHex: String
    let startDate: Date
    let userId: UUID
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case goal
        case colorHex = "color_hex"
        case startDate = "start_date"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from habit: Habit, userId: UUID) {
        self.id = habit.id
        self.name = habit.name
        self.goal = habit.goal
        self.colorHex = habit.color
        self.startDate = habit.startDate
        self.userId = userId
        self.createdAt = habit.createdAt
        self.updatedAt = Date()
        self.deletedAt = habit.deletedAt
    }

    func toHabit() -> Habit {
        Habit(
            id: id,
            name: name,
            goal: goal,
            color: colorHex,
            startDate: startDate,
            completedDates: [],
            userId: userId,
            syncStatus: .synced,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
