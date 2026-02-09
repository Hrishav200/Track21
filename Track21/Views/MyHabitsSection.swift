//
//  MyHabitsSection.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct MyHabitsSection: View {
    @Bindable var viewModel: HabitViewModel
    @Binding var selectedHabit: Habit?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Habits")
                .font(.system(size: 18, weight: .bold))
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
        Text("Completed Today ✓")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "5DD167"))
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteButton(for: habit)
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
    
    private func deleteButton(for habit: Habit) -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.deleteHabit(habit)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
