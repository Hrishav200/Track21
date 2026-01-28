//
//  habit.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import SwiftUI

struct Habit: Identifiable, Equatable, Codable {
    let id: UUID
    var userId: UUID?
    var name: String
    var goal: String
    var colorHex: String
    var frequency: HabitFrequency
    let startDate: Date
    var reminderTime: Date?
    var reminderEnabled: Bool
    var completedDates: [Date]
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var syncStatus: SyncStatus = .synced

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case goal
        case colorHex = "color_hex"
        case frequency
        case startDate = "start_date"
        case reminderTime = "reminder_time"
        case reminderEnabled = "reminder_enabled"
        case completedDates = "completed_dates"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncStatus = "sync_status"
    }

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        goal: String = "",
        colorHex: String = "5DD167",
        frequency: HabitFrequency = .daily,
        startDate: Date = Date(),
        reminderTime: Date? = nil,
        reminderEnabled: Bool = false,
        completedDates: [Date] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        syncStatus: SyncStatus = .synced
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.goal = goal
        self.colorHex = colorHex
        self.frequency = frequency
        self.startDate = startDate
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.completedDates = completedDates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatus = syncStatus
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var daysCompleted: Int {
        completedDates.count
    }

    var currentDay: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(days + 1, 21)
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 20, to: startDate) ?? startDate
    }

    func isCompletedToday() -> Bool {
        let calendar = Calendar.current
        return completedDates.contains { calendar.isDateInToday($0) }
    }

    func isCompleted(on date: Date) -> Bool {
        let calendar = Calendar.current
        return completedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    mutating func toggleCompletion(for date: Date = Date()) {
        let calendar = Calendar.current
        if let index = completedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) {
            completedDates.remove(at: index)
        } else {
            completedDates.append(date)
        }
        syncStatus = .pending
        updatedAt = Date()
    }
}

enum SyncStatus: String, Codable {
    case synced
    case pending
    case failed
}

enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case twentyOneDays = "21 days"
    case custom = "Custom"
}
