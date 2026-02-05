//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    let habit: Habit?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    private var todayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let habit = habit {
                        Text("Day \(habit.currentDay) of 21")
                            .font(.system(size: 20, weight: .bold))
                        Text("Start: \(dateFormatter.string(from: habit.startDate)) | End: \(dateFormatter.string(from: habit.endDate))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select a habit")
                            .font(.system(size: 20, weight: .bold))
                        Text("Tap a habit below to see its progress")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(todayFormatter.string(from: Date()))
                    .font(.system(size: 14, weight: .medium))
            }
            
            WeeklyCalendarView(habit: habit)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: -50)
    }
}

#Preview {
    DayProgressCard(habit: nil)
}
