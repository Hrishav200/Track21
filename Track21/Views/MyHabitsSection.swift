//
//  MyHabitsSection.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct MyHabitsSection: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService
    @Binding var selectedHabit: Habit?
    var selectedDate: Date
    @State private var habitToEdit: Habit?
    @State private var showingArchive = false

    /// Only habits still in an open, unfinished cycle appear on Home.
    private var activeHabits: [Habit] { viewModel.activeHabits }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var completedHabits: [Habit] {
        activeHabits.filter { $0.isCompleted(on: selectedDate) }
    }

    private var incompleteHabits: [Habit] {
        activeHabits.filter { !$0.isCompleted(on: selectedDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Habits")
                    .font(.title3)
                    .fontWeight(.bold)

                if !isToday {
                    Text("(\(formattedDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !viewModel.archivedHabits.isEmpty {
                    Button {
                        showingArchive = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                            Text("\(viewModel.archivedHabits.count)")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.12))
                        .cornerRadius(14)
                    }
                    .accessibilityLabel("Trophy Case, \(viewModel.archivedHabits.count) finished cycles")
                }
            }
            .padding(.horizontal, 4)

            if activeHabits.isEmpty {
                if viewModel.archivedHabits.isEmpty {
                    EmptyHabitsView()
                } else {
                    emptyActiveWithArchive
                }
            } else {
                habitsContent
            }

            if !viewModel.archivedHabits.isEmpty {
                archiveEntryRow
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: completedHabits.map(\.id))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: incompleteHabits.map(\.id))
        .clipped()
        .offset(y: -30)
        .sheet(item: $habitToEdit) { habit in
            EditHabitView(viewModel: viewModel, authService: authService, habit: habit)
        }
        .sheet(isPresented: $showingArchive) {
            HabitArchiveView(viewModel: viewModel)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var emptyActiveWithArchive: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.primary)
            Text("No active cycles")
                .font(.headline)
            Text("Your finished habits live in the Trophy Case. Tap + to start a new 21-day cycle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private var archiveEntryRow: some View {
        Button {
            showingArchive = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "trophy.fill")
                        .foregroundColor(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trophy Case")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(archiveSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Trophy Case")
    }

    private var archiveSubtitle: String {
        let n = viewModel.archivedHabits.count
        let wins = viewModel.archivedHabits.filter { HabitVictoryLogic.hasCompletedCycle($0) }.count
        if wins == n {
            return n == 1 ? "1 finished cycle" : "\(n) finished cycles"
        }
        return "\(n) ended · \(wins) perfected"
    }

    @ViewBuilder
    private var habitsContent: some View {
        if !incompleteHabits.isEmpty {
            ForEach(incompleteHabits, id: \.id) { habit in
                habitRow(for: habit)
            }
        }

        if !completedHabits.isEmpty {
            completedSectionHeader

            ForEach(completedHabits, id: \.id) { habit in
                habitRow(for: habit)
            }
        }
    }

    private var completedSectionHeader: some View {
        Text(isToday ? "Completed Today" : "Completed")
            .font(.headline)
            .foregroundColor(AppTheme.primary)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .transition(.opacity)
    }

    @ViewBuilder
    private func habitRow(for habit: Habit) -> some View {
        let isCompleted = habit.isCompleted(on: selectedDate)
        HabitCardView(
            habit: habit,
            isCompleted: isCompleted,
            isSelected: selectedHabit?.id == habit.id,
            onToggle: {
                let habitId = habit.id
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    if let live = viewModel.habits.first(where: { $0.id == habitId }) {
                        viewModel.toggleHabitCompletion(live, for: selectedDate)
                    }
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap(for: habit)
        }
        .id(habit.id)
        .transition(habitTransition(isCompleted: isCompleted))
        .contextMenu {
            Button {
                habitToEdit = habit
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteHabit(habit)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func habitTransition(isCompleted: Bool) -> AnyTransition {
        if isCompleted {
            return .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .top).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }

    private func handleTap(for habit: Habit) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedHabit?.id == habit.id {
                selectedHabit = nil
            } else {
                selectedHabit = habit
            }
        }
    }
}
