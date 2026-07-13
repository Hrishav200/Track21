//
//  HabitJourneyGrid.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import SwiftUI

struct HabitJourneyGrid: View {
    let habit: Habit

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var habitColor: Color {
        Color(hex: habit.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("21-Day Journey")
                    .font(.headline)
                Spacer()
                Text("Day \(habit.currentDay) of 21")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...21, id: \.self) { dayNumber in
                    dayCell(dayNumber: dayNumber)
                }
            }

            legend
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func dayCell(dayNumber: Int) -> some View {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: habit.startDate) ?? habit.startDate
        let status = habit.dateStatus(for: date)

        return RoundedRectangle(cornerRadius: 6)
            .fill(color(for: status))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Group {
                    if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else if status == .frozen {
                        Image(systemName: "snowflake")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(dayNumber)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(status == .missed ? .white : .secondary)
                    }
                }
            )
    }

    private func color(for status: HabitDateStatus) -> Color {
        switch status {
        case .completed: return habitColor
        case .frozen: return AppTheme.frozen
        case .missed: return AppTheme.missed
        case .future: return Color.gray.opacity(0.12)
        case .outside: return Color.gray.opacity(0.08)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: habitColor, label: "Done")
            legendItem(color: AppTheme.frozen, label: "Frozen")
            legendItem(color: AppTheme.missed, label: "Missed")
            legendItem(color: Color.gray.opacity(0.12), label: "Upcoming")
        }
        .padding(.top, 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HabitJourneyGrid(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"))
        .padding()
}
