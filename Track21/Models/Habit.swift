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
        deletedAt: Date? = nil
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
    
    // MARK: - Methods
    
    func isCompleted(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return completedDates.contains { calendar.startOfDay(for: $0) == targetDay }
    }
    
    func isCompletedToday() -> Bool {
        isCompleted(on: Date())
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
    case missed     // Amber - day passed, not tracked
    case future     // Empty - not yet reached
    case outside    // Outside the 21-day period
}
