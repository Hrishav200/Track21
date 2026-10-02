//
//  MiniJourneyStrip.swift
//  Track21
//
//  A compact, always-visible 21-day journey strip embedded directly in
//  every habit card on Home. The day-by-day grid is the whole point of a
//  21-day habit tracker, so instead of burying it one tab (and one habit
//  selection) away in Stats, a miniature version of it is the very first
//  thing you see on the screen you open every day.
//

import SwiftUI

struct MiniJourneyStrip: View {
    let habit: Habit

    private var habitColor: Color { Color(hex: habit.color) }
    private let calendar = Calendar.current
    private let spacing: CGFloat = 2.5

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = max((proxy.size.width - spacing * 20) / 21, 3)
            HStack(spacing: spacing) {
                ForEach(1...21, id: \.self) { dayNumber in
                    cell(for: dayNumber, width: cellWidth)
                }
            }
        }
        .frame(height: 14)
        // Decorative alongside the habit card's own accessibility summary
        // (name, streak, goal) — 21 separate VoiceOver stops per card would
        // drown that out rather than add useful detail.
        .accessibilityHidden(true)
    }

    private func cell(for dayNumber: Int, width: CGFloat) -> some View {
        // Always anchor off start-of-day so the strip lines up with
        // totalCompletions / cycleDaysAccounted window math.
        let start = calendar.startOfDay(for: habit.startDate)
        let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: start) ?? start
        let status = habit.dateStatus(for: date)
        let isToday = calendar.isDateInToday(date)

        return RoundedRectangle(cornerRadius: 2)
            .fill(fillColor(for: status))
            .frame(width: width, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(strokeColor(for: status, isToday: isToday), lineWidth: isToday ? 1.2 : 1)
            )
    }

    private func fillColor(for status: HabitDateStatus) -> Color {
        switch status {
        case .completed: return habitColor
        case .frozen: return AppTheme.frozen
        // Missed used to be solid amber — looked identical to a full
        // orange habit completion in Trophy Case (0/21 with "21 filled").
        case .missed: return Color.clear
        case .future: return Color.gray.opacity(0.12)
        case .outside: return Color.gray.opacity(0.08)
        }
    }

    private func strokeColor(for status: HabitDateStatus, isToday: Bool) -> Color {
        if isToday { return habitColor }
        switch status {
        case .missed: return AppTheme.missed.opacity(0.85)
        case .future, .outside: return Color.gray.opacity(0.28)
        case .completed, .frozen: return Color.clear
        }
    }
}

#Preview {
    let habit = Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF", startDate: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
    habit.completedDates = (0...6).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }

    return MiniJourneyStrip(habit: habit)
        .padding()
        .background(AppTheme.background)
}
