//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI
import Auth

struct ContentView: View {
    @Bindable var authService: AuthService
    @State private var viewModel = HabitViewModel()
    @State private var selectedTab = 0
    @State private var showingAddHabit = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                Text("Stats View")
                    .tag(1)
            }
            
            CustomTabBar(selectedTab: $selectedTab, showingAddHabit: $showingAddHabit)
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView()
        }
        .task {
            // Auto-sync when app opens
            if let userId = authService.currentUser?.id {
                await viewModel.syncWithCloud(userId: userId)
            }
        }
    }
}

