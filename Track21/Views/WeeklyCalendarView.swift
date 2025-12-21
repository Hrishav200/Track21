//
//  WeeklyCalendarView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct WeeklyCalendarView: View {
    let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let days = [14, 15, 16, 17, 18, 19, 20]
    let todayIndex = 3 // Wednesday
    let completedIndices = [1, 3, 4, 5] // Mon, Wed, Thu, Fri completed
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<7) { index in
                VStack(spacing: 4) {
                    Text(weekDays[index])
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(getColor(for: index))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Group {
                                if completedIndices.contains(index) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(days[index])")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        )
                }
            }
        }
    }
    
    func getColor(for index: Int) -> Color {
        if index == todayIndex {
            return Color(hex: "FFD700")
        } else if completedIndices.contains(index) {
            return Color(hex: "5DD167")
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}
