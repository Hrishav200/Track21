//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    let habit: Habit?
    let habits: [Habit]
    @Binding var selectedDate: Date
    @State private var weekOffset: Int = 0

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var selectedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, yyyy"
        return formatter
    }

    /// Label showing the week range, e.g. "Jan 20 – Jan 26"
    private var weekRangeLabel: String {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }

    // MARK: - Summary helpers

    private var completedTodayCount: Int {
        habits.filter { $0.isCompletedToday() }.count
    }

    private var totalTodayCount: Int {
        habits.count
    }

    private var progress: Double {
        guard totalTodayCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayCount)
    }

    private var motivationalMessage: String {
        guard totalTodayCount > 0 else { return "Add a habit to get started!" }
        let remaining = totalTodayCount - completedTodayCount
        switch completedTodayCount {
        case 0:
            return "Let's get started! 💪"
        case totalTodayCount:
            return "All done for today! 🎉"
        default:
            return remaining == 1 ? "One more to go!" : "Keep going, \(remaining) left!"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if let habit = habit {
                habitDetailHeader(habit: habit)
            } else {
                summaryHeader
            }

            weekNavigationRow

            if let habit = habit {
                WeeklyCalendarView(habit: habit, selectedDate: $selectedDate, weekOffset: weekOffset)
            } else {
                summaryCalendarRow
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: -50)
    }

    // MARK: - Habit detail header (existing behaviour)

    @ViewBuilder
    private func habitDetailHeader(habit: Habit) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(habit.currentDay) of 21")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Start: \(dateFormatter.string(from: habit.startDate)) | End: \(dateFormatter.string(from: habit.endDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(selectedDateFormatter.string(from: selectedDate))
                    .font(.subheadline)
                if !isToday || weekOffset != 0 {
                    backToTodayButton
                }
            }
        }
    }

    // MARK: - Summary header (no habit selected)

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppTheme.primary,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)

                VStack(spacing: 1) {
                    Text("\(completedTodayCount)")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Text("of \(totalTodayCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 68, height: 68)

            // Message + date
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Progress")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(selectedDateFormatter.string(from: selectedDate))
                    .font(.subheadline)
                if !isToday || weekOffset != 0 {
                    backToTodayButton
                }
            }
        }
    }

    // MARK: - Week navigation row

    private var weekNavigationRow: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    weekOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 28, height: 28)
            }

            Spacer()

            Text(weekRangeLabel)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    weekOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(weekOffset < 0 ? AppTheme.primary : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            .disabled(weekOffset >= 0)
        }
    }

    // MARK: - Summary calendar (all habits overview per day)

    private var summaryCalendarRow: some View {
        let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dates = summaryWeekDates

        return HStack(spacing: 12) {
            ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                VStack(spacing: 4) {
                    Text(weekDays[Calendar.current.component(.weekday, from: date) - 1])
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Circle()
                        .fill(summaryColor(for: date))
                        .frame(width: 36, height: 36)
                        .overlay(
                            summaryDayOverlay(for: date)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.primary : Color.clear,
                                    lineWidth: 2.5
                                )
                                .frame(width: 40, height: 40)
                        )
                        .onTapGesture {
                            if isSummaryTappable(date: date) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = Calendar.current.startOfDay(for: date)
                                }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryDayOverlay(for date: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let active = activeHabits(on: date)
        let completed = active.filter { $0.isCompleted(on: date) }.count

        if target <= today && !active.isEmpty && completed == active.count && active.count > 0 {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        } else {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(summaryTextColor(for: date))
        }
    }

    private var summaryWeekDates: [Date] {
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

    private func activeHabits(on date: Date) -> [Habit] {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        return habits.filter { habit in
            let start = calendar.startOfDay(for: habit.startDate)
            let end = calendar.startOfDay(for: habit.endDate)
            return target >= start && target <= end
        }
    }

    private func summaryColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        if target > today { return Color.gray.opacity(0.15) }

        let active = activeHabits(on: date)
        if active.isEmpty { return Color.gray.opacity(0.1) }

        let completed = active.filter { $0.isCompleted(on: date) }.count
        if completed == active.count { return AppTheme.primary }
        if completed > 0 { return AppTheme.missed }
        return Color.gray.opacity(0.25)
    }

    private func summaryTextColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        if target > today { return .gray }

        let active = activeHabits(on: date)
        if active.isEmpty { return .gray.opacity(0.5) }

        let completed = active.filter { $0.isCompleted(on: date) }.count
        return (completed > 0) ? .white : .gray
    }

    private func isSummaryTappable(date: Date) -> Bool {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return target <= today && !activeHabits(on: date).isEmpty
    }

    // MARK: - Shared

    private var backToTodayButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = Calendar.current.startOfDay(for: Date())
                weekOffset = 0
            }
        } label: {
            Text("Back to Today")
                .font(.caption2)
                .foregroundColor(AppTheme.primary)
        }
    }
}

#Preview {
    DayProgressCard(habit: nil, habits: [], selectedDate: .constant(Date()))
}
