//
//  HabitCardView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let isCompleted: Bool
    var isSelected: Bool = false
    var onToggle: () -> Void = {}
    
    var body: some View {
        HStack {
            // Status label on left
            Text(isCompleted ? "Done" : "To do")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isCompleted ? AppTheme.primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isCompleted ? AppTheme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(habit.currentStreak)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.orange)
                    }
                }

                Text("Goal: \(habit.goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Show day progress when selected
                if isSelected {
                    Text("Day \(habit.currentDay) of 21")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: habit.color))
                }
            }
            .padding(.leading, 8)

            Spacer()

            // Completion toggle button on right
            Button(action: onToggle) {
                Circle()
                    .fill(isCompleted ? AppTheme.primary : Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: isCompleted ? "checkmark" : "")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isCompleted ? "Mark \(habit.name) incomplete" : "Mark \(habit.name) complete")
        }
        .padding()
        .background(Color(hex: habit.color).opacity(isSelected ? 0.3 : 0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: habit.color) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}
