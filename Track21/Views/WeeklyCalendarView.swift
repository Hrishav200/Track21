//
//  WeeklyCalendarView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct WeeklyCalendarView: View {
    let habit: Habit?
    @Binding var selectedDate: Date
    var weekOffset: Int = 0
    let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let startOfOffsetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) else {
            return [today]
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfOffsetWeek)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(currentWeekDates.enumerated()), id: \.offset) { _, date in
                VStack(spacing: 4) {
                    Text(weekDays[Calendar.current.component(.weekday, from: date) - 1])
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Circle()
                        .fill(getColor(for: date))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Group {
                                if let habit = habit, habit.isCompleted(on: date) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                } else if let habit = habit, habit.isFrozen(on: date) {
                                    Image(systemName: "snowflake")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text(dayNumber(for: date))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(textColor(for: date))
                                }
                            }
                        )
                        .overlay(
                            // Ring highlight for selected date
                            Circle()
                                .stroke(isSelected(date) ? Color.primary : Color.clear, lineWidth: 2.5)
                                .frame(width: 40, height: 40)
                        )
                        .onTapGesture {
                            if isTappable(date: date) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = Calendar.current.startOfDay(for: date)
                                }
                            }
                        }
                }
            }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayNumber(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }

    private func getColor(for date: Date) -> Color {
        guard let habit = habit else {
            return Color.gray.opacity(0.3)
        }

        let status = habit.dateStatus(for: date)

        switch status {
        case .completed:
            return AppTheme.primary
        case .frozen:
            return AppTheme.frozen
        case .missed:
            return AppTheme.missed
        case .future:
            return Color.gray.opacity(0.15)
        case .outside:
            return Color.gray.opacity(0.1)
        }
    }

    /// A day is tappable if it's within the habit period and not in the
    /// future. Frozen days are locked — they're set automatically by the
    /// streak-freeze feature, not user-editable.
    private func isTappable(date: Date) -> Bool {
        guard let habit = habit else { return false }
        let status = habit.dateStatus(for: date)
        return status == .completed || status == .missed
    }

    private func textColor(for date: Date) -> Color {
        guard let habit = habit else {
            return .gray
        }

        let status = habit.dateStatus(for: date)

        switch status {
        case .completed:
            return .white
        case .frozen:
            return .white
        case .missed:
            return .white
        case .future:
            return .gray
        case .outside:
            return .gray.opacity(0.5)
        }
    }
}

// MARK: - Preview with no habit (fallback)
#Preview {
    WeeklyCalendarView(habit: nil, selectedDate: .constant(Date()))
}
