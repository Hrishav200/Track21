//
//  HabitCardView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct HabitCardView: View {
    @Bindable var habit: Habit
    let isCompleted: Bool
    var isSelected: Bool = false
    
    var body: some View {
        HStack {
            // Completion toggle button
            Button(action: {
                habit.toggleCompletion(for: Date())
            }) {
                Circle()
                    .fill(isCompleted ? Color(hex: "5DD167") : Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: isCompleted ? "checkmark" : "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Goal: \(habit.goal)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                // Show day progress when selected
                if isSelected {
                    Text("Day \(habit.currentDay) of 21")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: habit.color))
                }
            }
            .padding(.leading, 8)
            
            Spacer()
            
            Text(isCompleted ? "Done" : "To do")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isCompleted ? Color(hex: "5DD167") : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isCompleted ? Color(hex: "5DD167").opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(hex: habit.color).opacity(isSelected ? 0.3 : 0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: habit.color) : Color.clear, lineWidth: 2)
        )
    }
}
