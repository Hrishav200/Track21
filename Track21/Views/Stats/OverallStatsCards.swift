//
//  OverallStatsCards.swift
//  Track21
//
//  The "All" overview's stat tiles — mirrors StatsOverviewCards' layout
//  but rolled up across every habit instead of just one.
//

import SwiftUI

struct OverallStatsCards: View {
    let habits: [Habit]

    var body: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(StatsAggregation.longestCurrentStreak(for: habits))",
                label: "Longest Streak"
            )

            statTile(
                icon: "trophy.fill",
                iconColor: .yellow,
                value: "\(StatsAggregation.bestStreakEver(for: habits))",
                label: "Best Ever"
            )

            statTile(
                icon: "checkmark.seal.fill",
                iconColor: AppTheme.primary,
                value: "\(Int((StatsAggregation.overallCompletionRate(for: habits) * 100).rounded()))%",
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
    OverallStatsCards(habits: [
        Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF"),
        Habit(name: "Read", goal: "20 pages", color: "A78BFA")
    ])
    .padding()
}
