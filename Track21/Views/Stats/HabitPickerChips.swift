//
//  HabitPickerChips.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import SwiftUI

struct HabitPickerChips: View {
    let habits: [Habit]
    @Binding var selectedHabitID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                allChip
                ForEach(habits) { habit in
                    chip(for: habit)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Deselecting back to "nothing picked" is how you get to the overall
    /// (all-habits) stats view — this chip is the explicit way back there
    /// once you've drilled into a single habit.
    private var allChip: some View {
        let isSelected = selectedHabitID == nil

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHabitID = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption2)
                Text("All")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.primary : AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("All habits\(isSelected ? ", selected" : "")")
    }

    private func chip(for habit: Habit) -> some View {
        let isSelected = selectedHabitID == habit.id
        let color = Color(hex: habit.color)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHabitID = habit.id
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(habit.name)\(isSelected ? ", selected" : "")")
    }
}

#Preview {
    HabitPickerChips(
        habits: [
            Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"),
            Habit(name: "Read", goal: "20 pages", color: "A78BFA")
        ],
        selectedHabitID: .constant(nil)
    )
    .padding()
}
