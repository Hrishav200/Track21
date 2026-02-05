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
    @State private var selectedTab = 0
    @State private var showingAddHabit = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel)
                    .tag(0)
                
                StatsView()
                    .tag(1)
            }
            
            CustomTabBar(selectedTab: $selectedTab, showingAddHabit: $showingAddHabit)
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(viewModel: viewModel)
        }
        .task {
            // Set username from authenticated user
            if let user = authService.currentUser {
                let name = extractUserName(from: user)
                viewModel.saveUserName(name)
            }
            
            // Auto-sync when app opens
            if let userId = authService.currentUser?.id {
                await viewModel.syncWithCloud(userId: userId)
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
