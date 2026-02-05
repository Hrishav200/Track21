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
                if !viewModel.incompleteHabits.isEmpty {
                    ForEach(viewModel.incompleteHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: false,
                            isSelected: selectedHabit?.id == habit.id,
                            onToggle: { viewModel.toggleHabitCompletion(habit) }
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedHabit?.id == habit.id {
                                    selectedHabit = nil
                                } else {
                                    selectedHabit = habit
                                }
                            }
                        }
                    }
                }
                
                if !viewModel.completedHabits.isEmpty {
                    Text("Completed Today")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    
                    ForEach(viewModel.completedHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: true,
                            isSelected: selectedHabit?.id == habit.id,
                            onToggle: { viewModel.toggleHabitCompletion(habit) }
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedHabit?.id == habit.id {
                                    selectedHabit = nil
                                } else {
                                    selectedHabit = habit
                                }
                            }
                        }
                    }
                }
            }
        }
        .offset(y: -30)
    }
}
