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
            // Auto-sync when app opens
            if let userId = authService.currentUser?.id {
                await viewModel.syncWithCloud(userId: userId)
            }
        }
    }
}
