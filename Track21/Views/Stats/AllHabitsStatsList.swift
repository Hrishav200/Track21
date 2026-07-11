//
//  AllHabitsStatsList.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import SwiftUI

struct AllHabitsStatsList: View {
    let habits: [Habit]
    @Binding var selectedHabitID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Habits")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(habits) { habit in
                    row(for: habit)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func row(for habit: Habit) -> some View {
        let color = Color(hex: habit.color)
        let isSelected = selectedHabitID == habit.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHabitID = habit.id
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: habit.completionRate)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((habit.completionRate * 100).rounded()))")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("Day \(habit.currentDay) of 21")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("\(habit.currentStreak)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(Int((habit.completionRate * 100).rounded())) percent complete, \(habit.currentStreak) day streak")
    }
}

#Preview {
    AllHabitsStatsList(
        habits: [
            Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"),
            Habit(name: "Read", goal: "20 pages", color: "A78BFA")
        ],
        selectedHabitID: .constant(nil)
    )
    .padding()
}
