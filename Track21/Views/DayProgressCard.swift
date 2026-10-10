//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    /// Live view model — must observe the same source as the habit list so
    /// undoing a completion immediately redraws the week strip.
    @Bindable var viewModel: HabitViewModel
    let habit: Habit?
    @Binding var selectedDate: Date
    var onTap: () -> Void = {}
    @State private var weekOffset: Int = 0

    /// Home progress / week strip only count active (non-archived) cycles.
    private var habits: [Habit] { viewModel.activeHabits }
    private var completionRevision: Int { viewModel.completionRevision }

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
        // Touch revision so Observation always invalidates this card on toggle.
        let _ = completionRevision
        VStack(spacing: 16) {
            if let habit = habit {
                habitDetailHeader(habit: habit)
            } else {
                summaryHeader
            }

            weekNavigationRow

            if let habit = habit {
                WeeklyCalendarView(habit: habit, selectedDate: $selectedDate, weekOffset: weekOffset)
                    .id("habit-cal-\(habit.id)-\(completionRevision)-\(habitCompletionSignature(habit))")
            } else {
                summaryCalendarRow
                    .id("summary-cal-\(completionRevision)-\(fullCompletionSignature)")
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
                    .animation(.easeInOut(duration: 0.4), value: completionRevision)

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
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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

    private var weekDays: [String] { ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] }

    /// Fingerprint of every habit's completions — changes on any undo.
    private var fullCompletionSignature: String {
        let calendar = Calendar.current
        return habits.map { habit in
            let days = habit.completedDates
                .map { String(Int(calendar.startOfDay(for: $0).timeIntervalSince1970)) }
                .sorted()
                .joined(separator: ",")
            return "\(habit.id.uuidString):\(days)"
        }
        .joined(separator: "|")
    }

    private func habitCompletionSignature(_ habit: Habit) -> String {
        let calendar = Calendar.current
        let days = habit.completedDates
            .map { String(Int(calendar.startOfDay(for: $0).timeIntervalSince1970)) }
            .sorted()
            .joined(separator: ",")
        let frozen = habit.frozenDates
            .map { String(Int(calendar.startOfDay(for: $0).timeIntervalSince1970)) }
            .sorted()
            .joined(separator: ",")
        return "\(days);\(frozen)"
    }

    /// Green only when EVERY habit shown in the list for that day is
    /// completed — same set as the "3 of 4" progress ring.
    private func isFullyComplete(on date: Date) -> Bool {
        let shown = habitsShown(on: date)
        guard !shown.isEmpty else { return false }
        return shown.allSatisfy { $0.isCompleted(on: date) }
    }

    private func isFullyFrozen(on date: Date) -> Bool {
        let shown = habitsShown(on: date)
        guard !shown.isEmpty else { return false }
        let completed = shown.filter { $0.isCompleted(on: date) }.count
        let frozen = shown.filter { $0.isFrozen(on: date) }.count
        return frozen > 0 && completed + frozen == shown.count && completed < shown.count
    }

    private var summaryCalendarRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return HStack(spacing: 12) {
            ForEach(summaryWeekDates, id: \.timeIntervalSince1970) { date in
                let target = calendar.startOfDay(for: date)
                let shown = habitsShown(on: date)
                let fullyComplete = isFullyComplete(on: date)
                let fullyFrozen = isFullyFrozen(on: date)
                let completedCount = shown.filter { $0.isCompleted(on: date) }.count
                let frozenCount = shown.filter { $0.isFrozen(on: date) }.count
                let fill = summaryColor(
                    target: target,
                    today: today,
                    activeCount: shown.count,
                    fullyComplete: fullyComplete,
                    fullyFrozen: fullyFrozen,
                    completedCount: completedCount
                )
                let weekday = weekDays[calendar.component(.weekday, from: date) - 1]
                let namesSig = shown.map { "\($0.id.uuidString.prefix(4)):\($0.isCompleted(on: date))" }.joined(separator: ",")
                let cellId = "\(Int(target.timeIntervalSince1970))-\(fullyComplete)-\(completedCount)/\(shown.count)-\(frozenCount)-\(completionRevision)-\(namesSig)"

                VStack(spacing: 4) {
                    Text(weekday)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Circle()
                        .fill(fill)
                        .frame(width: 36, height: 36)
                        .overlay(summaryOverlay(
                            target: target,
                            today: today,
                            activeCount: shown.count,
                            fullyComplete: fullyComplete,
                            fullyFrozen: fullyFrozen,
                            dayNumber: "\(calendar.component(.day, from: date))",
                            textColor: summaryTextColor(
                                target: target,
                                today: today,
                                activeCount: shown.count,
                                completedCount: completedCount,
                                frozenCount: frozenCount
                            )
                        ))
                        .overlay(
                            Circle()
                                .stroke(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.primary : Color.clear, lineWidth: 2.5)
                                .frame(width: 40, height: 40)
                        )
                        .onTapGesture {
                            if target <= today && !shown.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = target
                                }
                            }
                        }
                }
                .id(cellId)
                .onAppear {
                    if calendar.isDateInToday(date) {
                        print("[Track21][calendar] today fullyComplete=\(fullyComplete) completed=\(completedCount)/\(shown.count) shown=\(shown.map(\.name)) rev=\(completionRevision)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryOverlay(
        target: Date,
        today: Date,
        activeCount: Int,
        fullyComplete: Bool,
        fullyFrozen: Bool,
        dayNumber: String,
        textColor: Color
    ) -> some View {
        if target <= today && activeCount > 0 && fullyComplete {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        } else if target <= today && activeCount > 0 && fullyFrozen {
            Image(systemName: "snowflake")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        } else {
            Text(dayNumber)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textColor)
        }
    }

    private var summaryWeekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let startOfOffsetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) else {
            return [today]
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfOffsetWeek)
        }
    }

    /// Habits that count toward the day strip — must match what
    /// MyHabitsSection / the progress ring show for that day.
    /// Previously filtered to each habit's 21-day window, which made Fri
    /// stay green when an expired habit (still listed) was incomplete.
    private func habitsShown(on date: Date) -> [Habit] {
        _ = date // same set for every day while the list shows all habits
        return habits
    }


    private func summaryColor(
        target: Date,
        today: Date,
        activeCount: Int,
        fullyComplete: Bool,
        fullyFrozen: Bool,
        completedCount: Int
    ) -> Color {
        if target > today { return Color.gray.opacity(0.15) }
        if activeCount == 0 { return Color.gray.opacity(0.1) }

        // Green ONLY when every shown habit is complete that day.
        if fullyComplete { return AppTheme.primary }

        if fullyFrozen { return AppTheme.frozen }

        if completedCount > 0 { return AppTheme.missed }
        return Color.gray.opacity(0.25)
    }

    private func summaryTextColor(
        target: Date,
        today: Date,
        activeCount: Int,
        completedCount: Int,
        frozenCount: Int
    ) -> Color {
        if target > today { return .gray }
        if activeCount == 0 { return .gray.opacity(0.5) }
        return (completedCount > 0 || frozenCount > 0) ? .white : .gray
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
