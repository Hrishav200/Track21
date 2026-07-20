//
//  OnboardingView.swift
//  Track21
//
//  One-time, skippable 3-page intro explaining the app's core mechanics —
//  shown as a fullScreenCover from ContentView the first time a user lands
//  in the app, before BuddyNamingView. Gated by a UserDefaults flag so it
//  never shows again after the first pass.
//

import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar.badge.checkmark",
            title: "The 21-Day Method",
            description: "It takes about 21 days of showing up for an action to start feeling like a habit. Track21 keeps you focused on one day at a time, for each 21-day cycle."
        ),
        OnboardingPage(
            icon: "snowflake",
            title: "Streak Freeze",
            description: "Life happens. A missed day doesn't have to break your streak — freezes protect it automatically, so one rough day doesn't undo your progress."
        ),
        OnboardingPage(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Meet Your Buddy",
            description: "Chat with an on-device AI companion who checks in and keeps you accountable. It runs entirely on your phone — nothing you say ever leaves it."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if pageIndex < pages.count - 1 {
                    Button("Skip", action: onFinish)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .accessibilityIdentifier("onboardingSkip")
                }
            }
            .frame(height: 44)

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(pageIndex == pages.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(14)
            }
            .accessibilityIdentifier("onboardingNext")
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundColor(AppTheme.primary)

            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func advance() {
        if pageIndex < pages.count - 1 {
            withAnimation { pageIndex += 1 }
        } else {
            onFinish()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
