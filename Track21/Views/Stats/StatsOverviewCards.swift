//
//  StatsOverviewCards.swift
//  Track21
//
//  A single habit's stat tiles — mirrors OverallStatsCards' layout but for
//  just this habit. Both share PremiumStatTile for the actual tile styling.
//

import SwiftUI

struct StatsOverviewCards: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 12) {
            PremiumStatTile(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(habit.currentStreak)",
                label: "Day Streak"
            )

            PremiumStatTile(
                icon: "trophy.fill",
                iconColor: .yellow,
                value: "\(habit.bestStreak)",
                label: "Best Streak"
            )

            PremiumStatTile(
                icon: "checkmark.seal.fill",
                iconColor: AppTheme.primary,
                value: "\(Int((habit.completionRate * 100).rounded()))%",
                label: "Completion"
            )
        }
    }
}

#Preview {
    StatsOverviewCards(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"))
        .padding()
        .background(AppTheme.background)
}
