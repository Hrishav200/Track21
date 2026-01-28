//
//  WeeklyCalendarView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct WeeklyCalendarView: View {
    var viewModel: HabitViewModel
    
    let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<7) { index in
                let date = Calendar.current.date(byAdding: .day, value: index - 3, to: Date()) ?? Date()
                let day = Calendar.current.component(.day, from: date)
                let isToday = Calendar.current.isDateInToday(date)
                
                VStack(spacing: 4) {
                    Text(weekDays[Calendar.current.component(.weekday, from: date) - 1])
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(isToday ? Color(hex: "FFD700") : Color(hex: "5DD167"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("\(day)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
            }
        }
    }
}
