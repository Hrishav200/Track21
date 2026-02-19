//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct ContentView: View {
    @Bindable var authService: AuthService
    @Bindable var viewModel: HabitViewModel
    @Bindable var profileService: ProfileService
    @State private var selectedTab = 0
    @State private var showingAddHabit = false
    @State private var showingProfile = false
    @State private var showGuestBanner = true

    var body: some View {
        ZStack(alignment: .bottom) {
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

                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel, authService: authService, onProfileTap: { showingProfile = true })
                        .tag(0)

                    StatsView()
                        .tag(1)
                }
            }

            CustomTabBar(selectedTab: $selectedTab, showingAddHabit: $showingAddHabit)
        }
        .edgesIgnoringSafeArea(.bottom)
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
        .task {
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
}
