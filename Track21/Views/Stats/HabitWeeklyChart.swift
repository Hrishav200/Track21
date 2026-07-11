//
//  HabitWeeklyChart.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import SwiftUI
import Charts

private struct DayCompletion: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let completed: Bool
}

struct HabitWeeklyChart: View {
    let habit: Habit

    private var days: [DayCompletion] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return (0..<7).reversed().compactMap { offset -> DayCompletion? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCompletion(
                date: date,
                label: formatter.string(from: date),
                completed: habit.isCompleted(on: date)
            )
        }
    }

    private var habitColor: Color {
        Color(hex: habit.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Completed", day.completed ? 1 : 0.06)
                )
                .foregroundStyle(day.completed ? habitColor : Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel("Completion for the last 7 days")
            .accessibilityValue(days.map { "\($0.label) \($0.completed ? "done" : "missed")" }.joined(separator: ", "))
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }
}

#Preview {
    HabitWeeklyChart(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"))
        .padding()
}
