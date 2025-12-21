//
//  HabitCardView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct HabitCardView: View {
    let habit: MockHabit
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Goal: \(habit.goal)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(isCompleted ? "Completed" : "Incomplete")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isCompleted ? Color(hex: "5DD167") : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isCompleted ? Color(hex: "5DD167").opacity(0.15) : Color.clear)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(hex: habit.color).opacity(0.15))
        .cornerRadius(12)
    }
}
