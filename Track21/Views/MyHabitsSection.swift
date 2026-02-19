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

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var completedHabits: [Habit] {
        viewModel.habits.filter { $0.isCompleted(on: selectedDate) }
    }

    private var incompleteHabits: [Habit] {
        viewModel.habits.filter { !$0.isCompleted(on: selectedDate) }
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
            }
            .padding(.horizontal, 4)

            if viewModel.habits.isEmpty {
                EmptyHabitsView()
            } else {
                habitsContent
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: completedHabits.map(\.id))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: incompleteHabits.map(\.id))
        .offset(y: -30)
        .sheet(item: $habitToEdit) { habit in
            EditHabitView(viewModel: viewModel, authService: authService, habit: habit)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    @ViewBuilder
    private var habitsContent: some View {
        // Incomplete habits section
        if !incompleteHabits.isEmpty {
            ForEach(incompleteHabits) { habit in
                habitRow(for: habit, isCompleted: false)
            }
        }

        // Completed habits section
        if !completedHabits.isEmpty {
            completedSectionHeader

            ForEach(completedHabits) { habit in
                habitRow(for: habit, isCompleted: true)
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
    private func habitRow(for habit: Habit, isCompleted: Bool) -> some View {
        HabitCardView(
            habit: habit,
            isCompleted: isCompleted,
            isSelected: selectedHabit?.id == habit.id,
            onToggle: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    viewModel.toggleHabitCompletion(habit, for: selectedDate)
                }
            }
        )
        .transition(habitTransition(isCompleted: isCompleted))
        .onTapGesture {
            handleTap(for: habit)
        }
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
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
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
