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
        let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: habit.startDate) ?? habit.startDate
        let status = habit.dateStatus(for: date)
        let isToday = calendar.isDateInToday(date)

        return RoundedRectangle(cornerRadius: 2)
            .fill(color(for: status))
            .frame(width: width, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isToday ? habitColor : Color.clear, lineWidth: 1.2)
            )
    }

    private func color(for status: HabitDateStatus) -> Color {
        switch status {
        case .completed: return habitColor
        case .frozen: return AppTheme.frozen
        case .missed: return AppTheme.missed
        case .future: return Color.gray.opacity(0.16)
        case .outside: return Color.gray.opacity(0.1)
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
