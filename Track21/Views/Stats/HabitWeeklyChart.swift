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
    let status: HabitDateStatus
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
                status: habit.dateStatus(for: date)
            )
        }
    }

    private var habitColor: Color {
        Color(hex: habit.color)
    }

    private func barHeight(for status: HabitDateStatus) -> Double {
        switch status {
        case .completed: return 1
        case .frozen: return 0.6
        default: return 0.06
        }
    }

    private func barColor(for status: HabitDateStatus) -> Color {
        switch status {
        case .completed: return habitColor
        case .frozen: return AppTheme.frozen
        default: return Color.gray.opacity(0.2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Completed", barHeight(for: day.status))
                )
                .foregroundStyle(barColor(for: day.status))
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel("Completion for the last 7 days")
            .accessibilityValue(days.map { "\($0.label) \(accessibilityWord(for: $0.status))" }.joined(separator: ", "))
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func accessibilityWord(for status: HabitDateStatus) -> String {
        switch status {
        case .completed: return "done"
        case .frozen: return "frozen"
        default: return "missed"
        }
    }
}

#Preview {
    HabitWeeklyChart(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"))
        .padding()
}
