//
//  HomeView.swift
//  Track21
//
//  Created by Hrishav Sunar on 13/10/2025.
//

import SwiftUI
internal import Auth


struct HomeView: View {
    var viewModel: HabitViewModel
    var authService: AuthService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel)
                
                VStack(spacing: 16) {
                    DayProgressCard(viewModel: viewModel)
                    
                    TodayProgressView(viewModel: viewModel)
                    
                    MyHabitsSection(viewModel: viewModel)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color(hex: "F5F5F5"))
        .edgesIgnoringSafeArea(.top)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Sync button
                    Button(action: {
                        Task {
                            if let userId = authService.currentUser?.id {
                                await viewModel.syncWithCloud(userId: userId)
                            }
                        }
                    }) {
                        if viewModel.isSyncing {
                            ProgressView()
                                .tint(Color(hex: "5DD167"))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color(hex: "5DD167"))
                        }
                    }
                    
                    // Sign out button
                    Button(action: {
                        Task {
                            try? await authService.signOut()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}
