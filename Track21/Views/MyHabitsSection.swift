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
    @State private var habitToEdit: Habit?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Habits")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 4)
            
            if viewModel.habits.isEmpty {
                EmptyHabitsView()
            } else {
                habitsContent
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.completedHabits.map(\.id))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.incompleteHabits.map(\.id))
        .offset(y: -30)
        .sheet(item: $habitToEdit) { habit in
            EditHabitView(viewModel: viewModel, authService: authService, habit: habit)
        }
    }
    
    @ViewBuilder
    private var habitsContent: some View {
        // Incomplete habits section
        if !viewModel.incompleteHabits.isEmpty {
            ForEach(viewModel.incompleteHabits) { habit in
                habitRow(for: habit, isCompleted: false)
            }
        }
        
        // Completed habits section
        if !viewModel.completedHabits.isEmpty {
            completedSectionHeader
            
            ForEach(viewModel.completedHabits) { habit in
                habitRow(for: habit, isCompleted: true)
            }
        }
    }
    
    private var completedSectionHeader: some View {
        Text("Completed Today")
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
                    viewModel.toggleHabitCompletion(habit)
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
