//
//  PremiumStatTile.swift
//  Track21
//
//  Shared stat-tile styling for both the "All habits" overview
//  (OverallStatsCards) and a single habit's detail view
//  (StatsOverviewCards) — previously duplicated in both. A tinted icon
//  badge, bolder rounded-design number and a touch of elevation replace
//  the old flat icon-over-number layout for a more "premium" feel.
//

import SwiftUI

struct PremiumStatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .statsCardStyle(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview {
    HStack(spacing: 12) {
        PremiumStatTile(icon: "flame.fill", iconColor: .orange, value: "12", label: "Day Streak")
        PremiumStatTile(icon: "trophy.fill", iconColor: .yellow, value: "21", label: "Best Streak")
        PremiumStatTile(icon: "checkmark.seal.fill", iconColor: AppTheme.primary, value: "87%", label: "Completion")
    }
    .padding()
    .background(AppTheme.background)
}
