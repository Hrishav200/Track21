//
//  OverallStatsCards.swift
//  Track21
//
//  The "All" overview's stat tiles — mirrors StatsOverviewCards' layout
//  but rolled up across every habit instead of just one. Both share
//  PremiumStatTile for the actual tile styling.
//

import SwiftUI

struct OverallStatsCards: View {
    let habits: [Habit]

    var body: some View {
        HStack(spacing: 12) {
            PremiumStatTile(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(StatsAggregation.longestCurrentStreak(for: habits))",
                label: "Longest Streak"
            )

            PremiumStatTile(
                icon: "trophy.fill",
                iconColor: .yellow,
                value: "\(StatsAggregation.bestStreakEver(for: habits))",
                label: "Best Ever"
            )

            PremiumStatTile(
                icon: "checkmark.seal.fill",
                iconColor: AppTheme.primary,
                value: "\(Int((StatsAggregation.overallCompletionRate(for: habits) * 100).rounded()))%",
                label: "Completion"
            )
        }
    }
}

#Preview {
    OverallStatsCards(habits: [
        Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"),
        Habit(name: "Read", goal: "20 pages", color: "A78BFA")
    ])
    .padding()
    .background(AppTheme.background)
}
