//
//  HeaderView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI
import UIKit

struct HeaderView: View {
    var viewModel: HabitViewModel
    var onProfileTap: () -> Void = {}

    private var bestStreak: Int {
        viewModel.habits.map(\.currentStreak).max() ?? 0
    }

    /// Read directly from the window rather than a GeometryReader — the
    /// ScrollView above this ignores the top safe area (so the green
    /// background can bleed under the status bar), and any GeometryReader
    /// nested inside an ignoring ancestor reports 0 for the ignored edge.
    /// Going straight to UIKit sidesteps that entirely.
    private var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 47
    }

    /// Extra breathing room below the status bar/Dynamic Island, on top of
    /// `topInset` — the single place that controls this gap, instead of
    /// repeating (or worse, a bare Spacer sitting outside the green
    /// background, which would show gray through the gap instead of green).
    private let headerContentTopSpacing: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Only the background bleeds under the status bar/Dynamic
            // Island — the text and profile button below are siblings that
            // don't ignore the safe area, so SwiftUI insets them by the
            // real per-device amount automatically, no hardcoded guess.
            AppTheme.primary
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text("Hi \(viewModel.userName)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Let's build habits today!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                if bestStreak > 0 || !viewModel.habits.isEmpty {
                    HStack(spacing: 8) {
                        if bestStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                Text(bestStreak == 1 ? "1 day streak" : "\(bestStreak) day streak")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(20)
                        }

                        if !viewModel.habits.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "snowflake")
                                    .font(.caption2)
                                Text(viewModel.isPremium ? "Unlimited freezes" : "\(viewModel.freezesAvailable) freezes")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(20)
                            .accessibilityLabel(viewModel.isPremium ? "Unlimited streak freezes" : "\(viewModel.freezesAvailable) streak freezes remaining")
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, topInset + headerContentTopSpacing)
            .padding(.bottom, 80)

            // Profile button
            Button(action: onProfileTap) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .font(.headline)
                            .foregroundColor(AppTheme.primary)
                    )
            }
            .accessibilityLabel("Profile")
            .accessibilityHint("Opens your profile settings")
            .padding(.top, topInset + headerContentTopSpacing)
            .padding(.trailing, 20)
        }
        .frame(height: 196)
    }

    private var initials: String {
        let name = viewModel.userName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}
