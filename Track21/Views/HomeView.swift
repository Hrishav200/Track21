//
//  HomeView.swift
//  Track21
//
//  Created by Hrishav Sunar on 13/10/2025.
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService
    @State private var selectedHabit: Habit?
    @State private var showingAddHabit = false
    var onProfileTap: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel, onProfileTap: onProfileTap)
                
                VStack(spacing: 16) {
                    DayProgressCard(habit: selectedHabit)
                    
                    TodayProgressView(viewModel: viewModel)
                    
                    MyHabitsSection(viewModel: viewModel, selectedHabit: $selectedHabit)
                    
                    // Add habit button
                    Button(action: { showingAddHabit = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Habit")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "5DD167"))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color(hex: "F5F5F5"))
        .edgesIgnoringSafeArea(.top)
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(viewModel: viewModel, authService: authService)
        }
        .onAppear {
            // Select first habit by default if none selected
            if selectedHabit == nil && !viewModel.habits.isEmpty {
                selectedHabit = viewModel.habits.first
            }
        }
    }
}
