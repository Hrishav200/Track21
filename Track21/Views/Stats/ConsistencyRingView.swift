//
//  ConsistencyRingView.swift
//  Track21
//
//  The Stats tab's headline visual — a big animated gradient progress
//  ring (Apple Activity-ring inspired) fronting either the aggregate
//  "All habits" completion rate or a single selected habit's. Exists to
//  give the tab one unmistakable hero number instead of starting cold on
//  a row of small tiles, which is what made the old layout feel more
//  like a spreadsheet than a habit app.
//

import SwiftUI

struct ConsistencyRingView: View {
    /// 0...1
    let progress: Double
    let ringColor: Color
    let title: String
    let subtitle: String
    /// Small badge under the title, e.g. "🔥 12 day streak" — nil hides it.
    let streakText: String?

    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [ringColor.opacity(0.55), ringColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int((progress * 100).rounded()))")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let streakText {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(streakText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(20)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
        .onAppear { animateIn() }
        .onChange(of: progress) { _, _ in animateIn() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Int((progress * 100).rounded())) percent, \(subtitle)")
    }

    private func animateIn() {
        animatedProgress = 0
        withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
            animatedProgress = min(max(progress, 0), 1)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ConsistencyRingView(
            progress: 0.87,
            ringColor: AppTheme.primary,
            title: "Overall Consistency",
            subtitle: "Across 3 habits",
            streakText: "12 day best streak"
        )
        ConsistencyRingView(
            progress: 0.62,
            ringColor: Color(hex: "A78BFA"),
            title: "Read",
            subtitle: "Day 13 of 21",
            streakText: "5 day streak"
        )
    }
    .padding()
    .background(AppTheme.background)
}
