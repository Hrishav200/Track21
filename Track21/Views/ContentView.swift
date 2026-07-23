//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI
import UIKit
internal import Auth

struct ContentView: View {
    @Bindable var authService: AuthService
    @Bindable var viewModel: HabitViewModel
    @Bindable var profileService: ProfileService
    @State private var selectedTab = 0
    @State private var lastRealTab = 0
    @State private var showingAddHabit = false
    @State private var showingProfile = false
    @State private var showGuestBanner = true
    @State private var freezeToastNames: [String] = []
    @State private var celebratingAchievements: [Achievement] = []
    @State private var buddyService = BuddyService.shared
    @State private var showBuddyNaming = false
    @AppStorage("Track21HasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            // Guest mode warning banner (auto-dismisses after 5s)
            if authService.isGuest && showGuestBanner {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.subheadline)
                    Text("Guest mode — data is not synced. Sign in to back up your habits.")
                        .font(.caption)
                    Spacer()
                    Button {
                        withAnimation { showGuestBanner = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Streak freeze auto-consumption toast (see protectStreaksIfNeeded())
            if !freezeToastNames.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.subheadline)
                    Text(freezeToastMessage)
                        .font(.caption)
                    Spacer()
                    Button {
                        withAnimation { freezeToastNames = [] }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.frozen)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Achievement-unlock celebration toast (see checkForNewAchievements())
            if !celebratingAchievements.isEmpty {
                HStack(spacing: 8) {
                    Text(celebratingAchievements.map(\.emoji).joined())
                        .font(.subheadline)
                    Text(achievementToastMessage)
                        .font(.caption)
                    Spacer()
                    Button {
                        withAnimation { celebratingAchievements = [] }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.purple)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            tabs
                .onChange(of: viewModel.recentlyUnlockedAchievements) { _, newly in
                    guard !newly.isEmpty else { return }
                    withAnimation { celebratingAchievements = newly }
                    viewModel.recentlyUnlockedAchievements = []
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        withAnimation { celebratingAchievements = [] }
                    }
                }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(viewModel: viewModel, authService: authService)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(
                authService: authService,
                profileService: profileService,
                viewModel: viewModel
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinish: {
                hasSeenOnboarding = true
                showOnboarding = false
                if !buddyService.hasNamedBuddy {
                    showBuddyNaming = true
                }
            })
        }
        .fullScreenCover(isPresented: $showBuddyNaming) {
            BuddyNamingView(onContinue: { name in
                buddyService.saveBuddyName(name)
                showBuddyNaming = false
            })
        }
        .task {
            if !hasSeenOnboarding {
                showOnboarding = true
            } else if !buddyService.hasNamedBuddy {
                showBuddyNaming = true
            }

            await NotificationService.shared.requestAuthorizationIfNeeded()

            let protectedHabits = viewModel.protectStreaksIfNeeded()
            if !protectedHabits.isEmpty {
                withAnimation { freezeToastNames = protectedHabits.map(\.name) }
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation { freezeToastNames = [] }
                }
            }

            buddyService.scheduleNudgeIfNeeded(for: viewModel.habits)
            viewModel.checkForNewAchievements()

            // Auto-dismiss guest banner after 5 seconds
            if authService.isGuest {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation { showGuestBanner = false }
                return
            }
            await loadUserProfile()

            // Auto-sync in the background so it doesn't block UI
            if let userId = authService.currentUser?.id {
                Task.detached { [viewModel] in
                    await viewModel.syncWithCloud(userId: userId)
                }
            }
        }
    }

    /// iOS 26's `Tab(role: .search)` is the only way to get a compact tab
    /// group with a separate, detached round accessory next to it (the
    /// same layout Photos uses for its search button) — a plain tab bar
    /// always stretches to fill the width regardless of item count, so
    /// there's no room beside it for a manually-overlaid button. The "Add"
    /// tab never actually shows a destination: selecting it immediately
    /// opens the Add Habit sheet and snaps back to whichever tab was
    /// showing, same trick as the previous "Add" tab used.
    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView(viewModel: viewModel, authService: authService, onProfileTap: { showingProfile = true }, onNavigateToStats: { selectedTab = 1 })
                }
                Tab("Statistics", systemImage: "chart.bar.fill", value: 1) {
                    StatsView(viewModel: viewModel)
                }
                Tab("Buddy", systemImage: "bubble.left.and.bubble.right.fill", value: 2) {
                    BuddyChatView(buddyName: buddyService.buddyName ?? "Buddy")
                }
                Tab("Achievements", systemImage: "trophy.fill", value: 3) {
                    AchievementsView(viewModel: viewModel)
                }
                Tab("Add", systemImage: "plus", value: 4, role: .search) {
                    Color.clear
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 4 {
                    showingAddHabit = true
                    selectedTab = lastRealTab
                } else {
                    lastRealTab = newValue
                }
            }
        } else {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel, authService: authService, onProfileTap: { showingProfile = true }, onNavigateToStats: { selectedTab = 1 })
                        .tag(0)
                        .tabItem { Label("Home", systemImage: "house.fill") }

                    StatsView(viewModel: viewModel)
                        .tag(1)
                        .tabItem { Label("Statistics", systemImage: "chart.bar.fill") }

                    BuddyChatView(buddyName: buddyService.buddyName ?? "Buddy")
                        .tag(2)
                        .tabItem { Label("Buddy", systemImage: "bubble.left.and.bubble.right.fill") }

                    AchievementsView(viewModel: viewModel)
                        .tag(3)
                        .tabItem { Label("Achievements", systemImage: "trophy.fill") }
                }

                FloatingAddButton(action: { showingAddHabit = true })
                    .padding(.trailing, 20)
                    .padding(.bottom, bottomSafeAreaInset)
            }
        }
    }

    private func loadUserProfile() async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            if let profile = try await profileService.fetchProfile(userId: userId) {
                // Show first name only (e.g. "Hrishav Sunar" → "Hrishav")
                let firstName = firstNameFrom(
                    fullName: profile.fullName,
                    fallback: profile.username
                )
                viewModel.saveUserName(firstName)
            } else {
                // No profile yet — use email prefix as fallback
                let fallback = authService.currentUser?.email?
                    .components(separatedBy: "@").first?.capitalized ?? "Friend"
                viewModel.saveUserName(fallback)
            }
        } catch {
            let fallback = authService.currentUser?.email?
                .components(separatedBy: "@").first?.capitalized ?? "Friend"
            viewModel.saveUserName(fallback)
        }
    }

    /// Extracts the first name from a full name string (e.g. "Hrishav Sunar" → "Hrishav")
    private func firstNameFrom(fullName: String?, fallback: String) -> String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName.components(separatedBy: " ").first ?? fullName
        }
        return fallback
    }

    private var freezeToastMessage: String {
        let names = freezeToastNames.joined(separator: ", ")
        return freezeToastNames.count == 1
            ? "Streak freeze used for \(names) — your streak is safe!"
            : "Streak freeze used for \(names) — your streaks are safe!"
    }

    private var achievementToastMessage: String {
        celebratingAchievements.count == 1
            ? "Achievement unlocked: \(celebratingAchievements[0].title)!"
            : "\(celebratingAchievements.count) achievements unlocked!"
    }

    /// Read straight from the window rather than a GeometryReader, matching
    /// HeaderView's approach — keeps this correct regardless of what any
    /// ancestor view does with safe areas.
    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 34
    }
}

/// The "+" action button, detached from the tab bar into its own floating
/// group — same Liquid Glass material (iOS 26+), tinted with the brand
/// color, with a solid-color fallback for older OS versions.
private struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .modifier(FloatingAddButtonBackground())
        }
        .accessibilityLabel("Add new habit")
    }
}

private struct FloatingAddButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(AppTheme.primary).interactive(), in: .circle)
        } else {
            content
                .background(AppTheme.primary)
                .clipShape(Circle())
                .shadow(color: AppTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)
        }
    }
}
