//
//  WeeklyCalendarView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct WeeklyCalendarView: View {
    let habit: Habit?
    let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(currentWeekDates.enumerated()), id: \.offset) { index, date in
                VStack(spacing: 4) {
                    Text(weekDays[index])
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(getColor(for: date))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Group {
                                if let habit = habit, habit.isCompleted(on: date) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text(dayNumber(for: date))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(textColor(for: date))
                                }
                            }
                        )
                }
            }
        }
    }
    
    private func dayNumber(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }
    
    private func getColor(for date: Date) -> Color {
        guard let habit = habit else {
            return Color.gray.opacity(0.3)
        }
        
        let status = habit.dateStatus(for: date)
        
        switch status {
        case .completed:
            return Color(hex: "5DD167") // Green
        case .missed:
            return Color(hex: "FFB347") // Amber
        case .future:
            return Color.gray.opacity(0.15) // Empty/light
        case .outside:
            return Color.gray.opacity(0.1) // Very light for outside period
        }
    }
    
    private func textColor(for date: Date) -> Color {
        guard let habit = habit else {
            return .gray
        }
        
        let status = habit.dateStatus(for: date)
        
        switch status {
        case .completed:
            return .white
        case .missed:
            return .white
        case .future:
            return .gray
        case .outside:
            return .gray.opacity(0.5)
        }
    }
}

// MARK: - Preview with no habit (fallback)
#Preview {
    WeeklyCalendarView(habit: nil)
}
