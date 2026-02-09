//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI
import Supabase
internal import Auth

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
            // Try to fetch profile from Supabase
            if let profile = try await profileService.fetchProfile(userId: userId) {
                // Use full name if available, otherwise username
                let displayName = profile.fullName ?? profile.username
                viewModel.saveUserName(displayName)
            } else {
                // No profile yet, use fallback from auth
                if let user = authService.currentUser {
                    let name = extractUserName(from: user)
                    viewModel.saveUserName(name)
                }
            }
        } catch {
            // Fallback to auth user data
            if let user = authService.currentUser {
                let name = extractUserName(from: user)
                viewModel.saveUserName(name)
            }
        }
    }
    
    private func extractUserName(from user: Auth.User) -> String {
        // Try to get name from user metadata first
        if let metadata = user.userMetadata["full_name"],
           case let .string(fullName) = metadata,
           !fullName.isEmpty {
            return fullName
        }
        
        // Fall back to first name from metadata
        if let metadata = user.userMetadata["name"],
           case let .string(name) = metadata,
           !name.isEmpty {
            return name
        }
        
        // Fall back to email prefix (before @)
        if let email = user.email {
            let prefix = email.components(separatedBy: "@").first ?? email
            return prefix.capitalized
        }
        
        return "Friend"
    }
}
