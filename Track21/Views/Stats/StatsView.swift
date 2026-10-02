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

    /// Active cycles, newest first.
    private var activeStatsHabits: [Habit] {
        viewModel.activeHabits.sorted { $0.createdAt > $1.createdAt }
    }

    /// Archived / finished cycles, newest first — shown as pills after actives.
    private var archivedStatsHabits: [Habit] {
        viewModel.archivedHabits.sorted { $0.createdAt > $1.createdAt }
    }

    /// Chip order: active habits, then archived habits.
    private var pickerHabits: [Habit] {
        activeStatsHabits + archivedStatsHabits
    }

    private var archivedIDs: Set<UUID> {
        Set(archivedStatsHabits.map(\.id))
    }

    /// `nil` when nothing's explicitly picked — that's the deliberate "All"
    /// overview (active habits only).
    private var selectedHabit: Habit? {
        guard let id = selectedHabitID else { return nil }
        return pickerHabits.first(where: { $0.id == id })
            ?? viewModel.habits.first(where: { $0.id == id })
    }

    /// Free users get full stats for whatever's currently in progress —
    /// once a habit's calendar window closes, its detailed history becomes
    /// a Pro feature rather than disappearing entirely.
    private func isLocked(_ habit: Habit) -> Bool {
        !habit.isActive && !viewModel.isPremium
    }

    private var hasAnyHabits: Bool {
        !pickerHabits.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .edgesIgnoringSafeArea(.all)

            // A faint brand-tinted wash behind the header only — just enough
            // to keep the tab from reading as a flat gray spreadsheet without
            // tinting the cards or charts below it.
            LinearGradient(
                colors: [AppTheme.primary.opacity(0.14), AppTheme.primary.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .frame(maxHeight: .infinity, alignment: .top)
            .edgesIgnoringSafeArea(.top)
            .allowsHitTesting(false)

            if hasAnyHabits {
                content
            } else {
                emptyState
            }
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: pickerHabits.map(\.id)) { _, _ in
            reconcileSelection()
        }
    }

    private func reconcileSelection() {
        // Drop a selection that no longer exists (deleted habit).
        if let id = selectedHabitID,
           !pickerHabits.contains(where: { $0.id == id }) {
            selectedHabitID = nil
        }
        // With exactly one habit (active or archived), skip straight to it.
        // With 0 or 2+, leave nil so All overview / empty state apply.
        if selectedHabitID == nil, pickerHabits.count == 1 {
            selectedHabitID = pickerHabits.first?.id
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if pickerHabits.count > 1 {
                    HabitPickerChips(
                        habits: pickerHabits,
                        selectedHabitID: $selectedHabitID,
                        archivedIDs: archivedIDs
                    )
                }

                if let habit = selectedHabit {
                    if isLocked(habit) {
                        lockedHistoryCard
                    } else {
                        ConsistencyRingView(
                            progress: habit.completionRate,
                            ringColor: Color(hex: habit.color),
                            title: habit.name,
                            subtitle: subtitle(for: habit),
                            streakText: habit.currentStreak > 0 ? "\(habit.currentStreak)-day streak" : nil
                        )
                        StatsOverviewCards(habit: habit)
                        HabitWeeklyChart(habit: habit)
                        HabitJourneyGrid(habit: habit)
                    }
                } else if !activeStatsHabits.isEmpty {
                    ConsistencyRingView(
                        progress: StatsAggregation.overallCompletionRate(for: activeStatsHabits),
                        ringColor: AppTheme.primary,
                        title: "Overall Consistency",
                        subtitle: activeStatsHabits.count == 1 ? "1 habit" : "\(activeStatsHabits.count) habits",
                        streakText: StatsAggregation.bestStreakEver(for: activeStatsHabits) > 0
                            ? "\(StatsAggregation.bestStreakEver(for: activeStatsHabits))-day best streak"
                            : nil
                    )
                    OverallStatsCards(habits: activeStatsHabits)
                    OverallCompletionChart(habits: activeStatsHabits)
                } else {
                    // No actives — All has nothing to aggregate; nudge to pick an archived chip.
                    archivedOnlyHint
                }

                if activeStatsHabits.count > 1 {
                    AllHabitsStatsList(
                        habits: activeStatsHabits,
                        selectedHabitID: $selectedHabitID,
                        isPremium: viewModel.isPremium
                    )
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

    private func subtitle(for habit: Habit) -> String {
        if archivedIDs.contains(habit.id) {
            let accounted = habit.cycleDaysAccounted
            if HabitVictoryLogic.hasCompletedCycle(habit) {
                return "Completed · \(accounted)/21"
            }
            return "Archived · \(accounted)/21"
        }
        return "Day \(habit.currentDay) of 21"
    }

    private var archivedOnlyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No active habits")
                .font(.headline)
            Text("Pick an archived habit above to see its stats.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .statsCardStyle(cornerRadius: 20)
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
                .background(AppTheme.primary.gradient)
                .cornerRadius(12)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .statsCardStyle(cornerRadius: 20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stats")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.heavy)
            Text("Your habit journey at a glance")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)

            Text("No habits yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add a habit and start tracking to see your progress here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

#Preview {
    StatsView(viewModel: HabitViewModel())
}
