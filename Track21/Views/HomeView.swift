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
    var onProfileTap: () -> Void = {}
    var onNavigateToStats: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel, onProfileTap: onProfileTap)

                VStack(spacing: 16) {
                    DayProgressCard(habit: selectedHabit, habits: viewModel.habits, selectedDate: $selectedDate, onTap: onNavigateToStats)

                    MyHabitsSection(
                        viewModel: viewModel,
                        authService: authService,
                        selectedHabit: $selectedHabit,
                        selectedDate: selectedDate
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(AppTheme.background)
        .edgesIgnoringSafeArea(.top)
        .onTapGesture {
            // Tapping a habit row consumes its own tap gesture first, so
            // this only ever fires for taps elsewhere on the screen.
            withAnimation(.easeInOut(duration: 0.2)) { selectedHabit = nil }
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
