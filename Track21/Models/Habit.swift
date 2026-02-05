//
//  Habit.swift
//  Track21
//
//  Created by GOLU on 5/2/2026.
//

import Foundation
import SwiftData

@Model
final class Habit {
    var name: String
    var goal: String
    var color: String
    var startDate: Date
    var completedDates: [Date]
    
    init(name: String, goal: String, color: String, startDate: Date = Date()) {
        self.name = name
        self.goal = goal
        self.color = color
        self.startDate = startDate
        self.completedDates = []
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
    
    func toggleCompletion(for date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        if let index = completedDates.firstIndex(where: { calendar.startOfDay(for: $0) == targetDay }) {
            completedDates.remove(at: index)
        } else {
            completedDates.append(targetDay)
        }
    }
    
    /// Returns the status of a date for this habit
    /// - green: completed
    /// - amber: missed (past date, not completed, within habit period)
    /// - empty: future or outside habit period
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
