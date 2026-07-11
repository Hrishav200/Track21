//
//  StatsView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: HabitViewModel
    @State private var selectedHabitID: UUID?

    private var selectedHabit: Habit? {
        if let id = selectedHabitID, let habit = viewModel.habits.first(where: { $0.id == id }) {
            return habit
        }
        return viewModel.habits.first
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .edgesIgnoringSafeArea(.all)

            if viewModel.habits.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .onAppear {
            if selectedHabitID == nil {
                selectedHabitID = viewModel.habits.first?.id
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if viewModel.habits.count > 1 {
                    HabitPickerChips(habits: viewModel.habits, selectedHabitID: $selectedHabitID)
                }

                if let habit = selectedHabit {
                    StatsOverviewCards(habit: habit)
                    HabitWeeklyChart(habit: habit)
                    HabitJourneyGrid(habit: habit)
                }

                if viewModel.habits.count > 1 {
                    AllHabitsStatsList(habits: viewModel.habits, selectedHabitID: $selectedHabitID)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 100)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Statistics")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your habit journey at a glance")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)

            Text("No stats yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add a habit and start tracking to see your progress here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatsView(viewModel: HabitViewModel())
}
