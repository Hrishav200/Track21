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
                    DayProgressCard(habit: selectedHabit, selectedDate: $selectedDate)

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
        .onAppear {
            selectTopHabitIfNeeded()
        }
        .onChange(of: viewModel.habits.count) {
            selectTopHabitIfNeeded()
        }
        .onChange(of: viewModel.lastSyncDate) {
            selectTopHabitIfNeeded()
        }
    }

    /// Selects the topmost habit (first incomplete, or first completed if all done).
    /// Also refreshes selectedHabit to the current object from viewModel.habits
    /// in case cloud sync replaced the array with new Habit instances.
    private func selectTopHabitIfNeeded() {
        if let current = selectedHabit,
           let refreshed = viewModel.habits.first(where: { $0.id == current.id }) {
            selectedHabit = refreshed
        } else if selectedHabit == nil || !viewModel.habits.contains(where: { $0.id == selectedHabit?.id }) {
            selectedHabit = viewModel.incompleteHabits.first ?? viewModel.completedHabits.first
        }
    }
}
