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
    @State private var showingPaywall = false

    /// `nil` when nothing's explicitly picked — that's not "no selection
    /// yet," it's the deliberate "All" state shown by the overview below.
    private var selectedHabit: Habit? {
        guard let id = selectedHabitID else { return nil }
        return viewModel.habits.first(where: { $0.id == id })
    }

    /// Free users get full stats for whatever's currently in progress —
    /// once a habit's 21-day cycle ends, its detailed history becomes a
    /// Pro feature rather than disappearing entirely (it still shows up in
    /// the picker/list, just locked).
    private func isLocked(_ habit: Habit) -> Bool {
        !habit.isActive && !viewModel.isPremium
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
            // With exactly one habit, "All" and "this habit" show the same
            // thing but the single-habit view is strictly more detailed
            // (weekly chart, 21-day grid) — so skip straight to it. With
            // 0 or 2+ habits, leave selection nil: 0 hits the empty state,
            // 2+ starts on the overview.
            if selectedHabitID == nil, viewModel.habits.count == 1 {
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
                    if isLocked(habit) {
                        lockedHistoryCard
                    } else {
                        StatsOverviewCards(habit: habit)
                        HabitWeeklyChart(habit: habit)
                        HabitJourneyGrid(habit: habit)
                    }
                } else {
                    OverallStatsCards(habits: viewModel.habits)
                    OverallCompletionChart(habits: viewModel.habits)
                }

                if viewModel.habits.count > 1 {
                    AllHabitsStatsList(habits: viewModel.habits, selectedHabitID: $selectedHabitID, isPremium: viewModel.isPremium)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(trigger: .lockedStats)
        }
    }

    private var lockedHistoryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("This cycle has ended")
                .font(.headline)

            Text("Full stats for completed cycles are a Track21 Pro feature. Go Pro to see every day's detail, not just what's in progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("Go Pro") { showingPaywall = true }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.primary)
                .cornerRadius(12)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stats")
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
