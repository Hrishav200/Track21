//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI
internal import Auth

struct ContentView: View {
    @Bindable var authService: AuthService
    @Bindable var viewModel: HabitViewModel
    @Bindable var profileService: ProfileService
    @State private var selectedTab = 0
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
        .fullScreenCover(item: $viewModel.recentHabitVictory) { habit in
            HabitVictoryView(habit: habit) {
                viewModel.recentHabitVictory = nil
            }
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

    /// A fully custom bottom bar rather than SwiftUI's native `TabView`
    /// chrome. Two things it was tried with first both failed to reliably
    /// place the "+" as a separate section actually *in* the bar rather
    /// than floating above it: iOS 26's `Tab(role: .search)` is supposed to
    /// split a detached accessory out from the main group, but on-device it
    /// can silently degrade into an ordinary sixth tab item; a manually
    /// overlaid button positioned by guessing at the system tab bar's
    /// height/margins landed visibly above the bar instead of level with
    /// it, since that geometry isn't something SwiftUI exposes to measure.
    /// Owning the whole row ourselves — a capsule with the four tab buttons
    /// plus a separate circular "+" — makes "in the bar, same row" true by
    /// construction instead of something to line up against guesswork.
    ///
    /// All four screens stay mounted simultaneously (opacity-toggled, not
    /// switched via `if`/`switch`) so each keeps its own scroll position
    /// and state while off-screen, matching what TabView already did.
    private var tabs: some View {
        VStack(spacing: 0) {
            ZStack {
                HomeView(viewModel: viewModel, authService: authService, onProfileTap: { showingProfile = true }, onNavigateToStats: { selectedTab = 1 })
                    .tabPageStyle(isActive: selectedTab == 0)
                StatsView(viewModel: viewModel)
                    .tabPageStyle(isActive: selectedTab == 1)
                BuddyChatView(buddyName: buddyService.buddyName ?? "Buddy", viewModel: viewModel, authService: authService)
                    .tabPageStyle(isActive: selectedTab == 2)
                JournalView(viewModel: viewModel, authService: authService)
                    .tabPageStyle(isActive: selectedTab == 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                tabBarButton(icon: "house.fill", label: "Home", tag: 0)
                tabBarButton(icon: "chart.bar.fill", label: "Stats", tag: 1)
                tabBarButton(icon: "bubble.left.and.bubble.right.fill", label: "Buddy", tag: 2)
                tabBarButton(icon: "book.fill", label: "Journal", tag: 3)
            }
            .frame(height: 56)
            .modifier(GlassBarBackground(shape: Capsule()))

            Button {
                showingAddHabit = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
            }
            .modifier(GlassBarBackground(shape: Circle()))
            .accessibilityLabel("Add new habit")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func tabBarButton(icon: String, label: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

}

/// Shared "Liquid Glass" surface for the custom bottom bar's two pieces
/// (the capsule tab group and the circular "+"), parametrized by shape so
/// one modifier serves both. Same material on iOS 26+ as the system tab
/// bar; a frosted-material fallback for older OS versions.
private struct GlassBarBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
    }
}

private extension View {
    /// One tab page in the custom bar's content stack: visible+interactive
    /// only when active, but always mounted — so switching tabs doesn't
    /// reset scroll position or navigation state the way tearing the view
    /// down and rebuilding it would.
    func tabPageStyle(isActive: Bool) -> some View {
        self
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}
