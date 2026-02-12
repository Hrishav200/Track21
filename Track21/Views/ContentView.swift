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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel, authService: authService, onProfileTap: { showingProfile = true })
                    .tag(0)
                
                StatsView()
                    .tag(1)
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
            await loadUserProfile()
            
            // Auto-sync when app opens
            if let userId = authService.currentUser?.id {
                await viewModel.syncWithCloud(userId: userId)
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
