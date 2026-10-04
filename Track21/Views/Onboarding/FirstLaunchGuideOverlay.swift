//
//  FirstLaunchGuideOverlay.swift
//  Track21
//
//  Short first-launch coach: add a habit, mark it done, open Stats, write in Journal, and chat with Buddy.
//  Skip or Got it persists the seen flag. Not a second onboarding essay.
//

import SwiftUI

struct FirstLaunchGuideOverlay: View {
    let onFinish: () -> Void

    @State private var index = 0

    private struct Step {
        let symbol: String
        let title: String
        let line: String
    }

    private let steps: [Step] = [
        Step(
            symbol: "plus",
            title: "Add a habit",
            line: "Tap + and name what you’ll do for 21 days."
        ),
        Step(
            symbol: "checkmark",
            title: "Mark it done",
            line: "When you finish, tap the circle on that habit."
        ),
        Step(
            symbol: "chart.bar.fill",
            title: "View stats",
            line: "Open Stats for your streak and 21-day progress."
        ),
        Step(
            symbol: "book.fill",
            title: "Write in Journal",
            line: "Capture how your day feels and keep your progress personal."
        ),
        Step(
            symbol: "bubble.left.and.bubble.right.fill",
            title: "Chat with Buddy",
            line: "Ask Buddy for a little guidance whenever you need it."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("\(index + 1) of \(steps.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Button("Skip", action: onFinish)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("firstLaunchGuideSkip")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer(minLength: 0)

                card
                    .padding(.horizontal, 20)
                    // Keeps the real + and Stats tab visible underneath.
                    .padding(.bottom, 118)
            }
        }
        .accessibilityIdentifier("firstLaunchGuide")
    }

    private var card: some View {
        let step = steps[index]
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { offset, item in
                    demoChip(item.symbol, active: offset == index)
                }
                Spacer(minLength: 0)
            }

            Text(step.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(step.line)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: advance) {
                Text(index == steps.count - 1 ? "Got it" : "Next")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityIdentifier("firstLaunchGuideNext")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.primary.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.28), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(step.title). \(step.line)")
    }

    private func demoChip(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.bold))
            .foregroundStyle(active ? Color.white : AppTheme.primary)
            .frame(width: 44, height: 44)
            .background(active ? AppTheme.primary : AppTheme.primary.opacity(0.16))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func advance() {
        if index < steps.count - 1 {
            withAnimation(.spring(duration: 0.32)) { index += 1 }
        } else {
            onFinish()
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        FirstLaunchGuideOverlay(onFinish: {})
    }
}
