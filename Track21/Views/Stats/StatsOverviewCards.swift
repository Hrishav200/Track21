//
//  StatsOverviewCards.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import SwiftUI

struct StatsOverviewCards: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(habit.currentStreak)",
                label: habit.currentStreak == 1 ? "Day Streak" : "Day Streak"
            )

            statTile(
                icon: "trophy.fill",
                iconColor: .yellow,
                value: "\(habit.bestStreak)",
                label: "Best Streak"
            )

            statTile(
                icon: "checkmark.seal.fill",
                iconColor: AppTheme.primary,
                value: "\(Int((habit.completionRate * 100).rounded()))%",
                label: "Completion"
            )
        }
    }

    private func statTile(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview {
    StatsOverviewCards(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"))
        .padding()
}
