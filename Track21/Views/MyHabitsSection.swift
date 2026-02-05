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
                // Incomplete habits section
                if !viewModel.incompleteHabits.isEmpty {
                    ForEach(viewModel.incompleteHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: false,
                            isSelected: selectedHabit?.id == habit.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.toggleHabitCompletion(habit)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
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
                
                // Completed habits section
                if !viewModel.completedHabits.isEmpty {
                    Text("Completed Today ✓")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "5DD167"))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .transition(.opacity)
                    
                    ForEach(viewModel.completedHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: true,
                            isSelected: selectedHabit?.id == habit.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.toggleHabitCompletion(habit)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.completedHabits.map(\.id))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.incompleteHabits.map(\.id))
        .offset(y: -30)
    }
}
