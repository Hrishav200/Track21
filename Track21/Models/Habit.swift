//
//  Habit.swift
//  Track21
//
//  Created by GOLU on 5/2/2026.
//

import Foundation

enum SyncStatus: String, Codable {
    case pending
    case synced
    case error
}

@Observable
final class Habit: Codable, Identifiable {
    var id: UUID
    var name: String
    var goal: String
    var color: String
    var startDate: Date
    var completedDates: [Date]
    var userId: UUID?
    var syncStatus: SyncStatus
    var createdAt: Date
    var updatedAt: Date?
    var deletedAt: Date?
    /// Time-of-day for a daily reminder notification. Only the hour/minute
    /// are used. `nil` means no reminder is scheduled. Local-only — there's
    /// no `reminder_time` column in Supabase, so this doesn't sync across
    /// devices (local notifications wouldn't carry over anyway).
    var reminderTime: Date?
    /// Days protected by a streak freeze — missed, but don't break the
    /// streak. Set by StreakFreezeService, not by the user directly.
    /// Local-only, same reasoning as reminderTime.
    var frozenDates: [Date]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case goal
        case color
        case startDate = "start_date"
        case completedDates = "completed_dates"
        case userId = "user_id"
        case syncStatus = "sync_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case reminderTime = "reminder_time"
        case frozenDates = "frozen_dates"
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        name: String,
        goal: String,
        color: String,
        startDate: Date = Date(),
        completedDates: [Date] = [],
        userId: UUID? = nil,
        syncStatus: SyncStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        reminderTime: Date? = nil,
        frozenDates: [Date] = []
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.color = color
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.completedDates = completedDates.map { Calendar.current.startOfDay(for: $0) }
        self.userId = userId
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.reminderTime = reminderTime
        self.frozenDates = frozenDates.map { Calendar.current.startOfDay(for: $0) }
    }

    // MARK: - Codable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        goal = try container.decode(String.self, forKey: .goal)
        color = try container.decode(String.self, forKey: .color)
        startDate = try container.decode(Date.self, forKey: .startDate)
        completedDates = try container.decodeIfPresent([Date].self, forKey: .completedDates) ?? []
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pending
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        frozenDates = try container.decodeIfPresent([Date].self, forKey: .frozenDates) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(goal, forKey: .goal)
        try container.encode(color, forKey: .color)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(completedDates, forKey: .completedDates)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(syncStatus, forKey: .syncStatus)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(reminderTime, forKey: .reminderTime)
        try container.encode(frozenDates, forKey: .frozenDates)
    }
    
    // MARK: - Computed Properties
    
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 20, to: startDate) ?? startDate
    }
    
    var currentDay: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: start, to: today)
        let dayNumber = (components.day ?? 0) + 1
        return min(max(dayNumber, 1), 21)
    }
    
    var isActive: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDate)
        return today <= end
    }

    /// Number of days from `startDate` through today (or `endDate`, whichever is sooner).
    var elapsedDaysCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: min(Date(), endDate))
        guard end >= start else { return 0 }
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    /// Total number of days marked complete within the 21-day window.
    var totalCompletions: Int {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return completedDates.filter { $0 >= start && $0 <= end }.count
    }

    /// Fraction of elapsed days (0...1) that were completed.
    var completionRate: Double {
        guard elapsedDaysCount > 0 else { return 0 }
        return Double(totalCompletions) / Double(elapsedDaysCount)
    }

    /// Total number of days protected by a streak freeze within the 21-day
    /// window. A day is either completed, frozen, or missed — never more
    /// than one — so `totalCompletions + totalFrozen` is the count of days
    /// that didn't break the streak.
    var totalFrozen: Int {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return frozenDates.filter { $0 >= start && $0 <= end }.count
    }

    /// Consecutive completed-or-frozen days counting back from today. A day
    /// that hasn't ended yet (i.e. today, if not yet completed) doesn't
    /// break the streak. A frozen day counts as continuing the streak
    /// (protects it) but isn't a real completion.
    var currentStreak: Int {
        currentStreak(asOf: Date())
    }

    /// Same as `currentStreak`, but anchored at an arbitrary reference date
    /// instead of "now" — used by StreakFreezeLogic to check whether a
    /// habit had an active streak going into a specific missed day.
    func currentStreak(asOf referenceDate: Date) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: referenceDate)
        let start = calendar.startOfDay(for: startDate)

        if !isCompleted(on: day), !isFrozen(on: day) {
            guard day > start, let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previousDay
        }

        var streak = 0
        while day >= start, isCompleted(on: day) || isFrozen(on: day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Longest run of consecutive completed-or-frozen days within the
    /// 21-day window so far.
    var bestStreak: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: min(Date(), endDate))
        guard end >= start else { return 0 }

        var best = 0
        var current = 0
        var day = start
        while day <= end {
            if isCompleted(on: day) || isFrozen(on: day) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    // MARK: - Methods
    
    func isCompleted(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return completedDates.contains { calendar.startOfDay(for: $0) == targetDay }
    }
    
    func isCompletedToday() -> Bool {
        isCompleted(on: Date())
    }

    func isFrozen(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return frozenDates.contains { calendar.startOfDay(for: $0) == targetDay }
    }

    func toggleCompletion(for date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        if let index = completedDates.firstIndex(where: { calendar.startOfDay(for: $0) == targetDay }) {
            completedDates.remove(at: index)
        } else {
            completedDates.append(targetDay)
        }
        syncStatus = .pending
        updatedAt = Date()
    }
    
    func toggleCompletion() {
        toggleCompletion(for: Date())
    }
    
    /// Returns the status of a date for this habit
    func dateStatus(for date: Date) -> HabitDateStatus {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let today = calendar.startOfDay(for: Date())
        
        // Outside habit period
        if targetDay < start || targetDay > end {
            return .outside
        }
        
        // Completed
        if isCompleted(on: date) {
            return .completed
        }

        // Protected by a streak freeze
        if isFrozen(on: date) {
            return .frozen
        }

        // Future (not yet reached)
        if targetDay > today {
            return .future
        }

        // Past and not completed = missed
        return .missed
    }
}

// MARK: - Date Status Enum

enum HabitDateStatus {
    case completed  // Green - tracked and completed
    case frozen     // Ice blue - missed, but protected by a streak freeze
    case missed     // Amber - day passed, not tracked
    case future     // Empty - not yet reached
    case outside    // Outside the 21-day period
}
