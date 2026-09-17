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

    @State private var animateIn = false

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
        guard animateIn else { return 0.02 }
        switch status {
        case .completed: return 1
        case .frozen: return 0.6
        default: return 0.06
        }
    }

    private func barStyle(for status: HabitDateStatus) -> AnyShapeStyle {
        switch status {
        case .completed: return AnyShapeStyle(habitColor.gradient)
        case .frozen: return AnyShapeStyle(AppTheme.frozen.gradient)
        default: return AnyShapeStyle(Color.gray.opacity(0.2))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(.headline, design: .rounded))

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Completed", barHeight(for: day.status))
                )
                .foregroundStyle(barStyle(for: day.status))
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel("Completion for the last 7 days")
            .accessibilityValue(days.map { "\($0.label) \(accessibilityWord(for: $0.status))" }.joined(separator: ", "))
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                animateIn = true
            }
        }
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
