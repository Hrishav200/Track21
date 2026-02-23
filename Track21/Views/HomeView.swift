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
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAddHabit = false
    var onProfileTap: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel, onProfileTap: onProfileTap)

                VStack(spacing: 16) {
                    DayProgressCard(habit: selectedHabit, habits: viewModel.habits, selectedDate: $selectedDate)

                    TodayProgressView(viewModel: viewModel, selectedDate: selectedDate)

                    MyHabitsSection(
                        viewModel: viewModel,
                        authService: authService,
                        selectedHabit: $selectedHabit,
                        selectedDate: selectedDate
                    )

                    // Add habit button
                    Button(action: { showingAddHabit = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Habit")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Add new habit")
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(AppTheme.background)
        .edgesIgnoringSafeArea(.top)
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(viewModel: viewModel, authService: authService)
        }
        .onChange(of: viewModel.habits.count) {
            refreshSelectedHabit()
        }
        .onChange(of: viewModel.lastSyncDate) {
            refreshSelectedHabit()
        }
    }

    /// Keeps selectedHabit in sync with viewModel.habits without auto-selecting.
    /// - If the selected habit still exists, refreshes its reference (in case sync replaced objects).
    /// - If the selected habit was deleted, clears the selection to show the summary.
    private func refreshSelectedHabit() {
        guard let current = selectedHabit else { return }
        if let refreshed = viewModel.habits.first(where: { $0.id == current.id }) {
            selectedHabit = refreshed
        } else {
            selectedHabit = nil
        }
    }
}
