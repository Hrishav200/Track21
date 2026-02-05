//
//  MyHabitsSection.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI
import SwiftData

struct MyHabitsSection: View {
    @Query private var habits: [Habit]
    @Binding var selectedHabit: Habit?
    
    private var incompleteHabits: [Habit] {
        habits.filter { !$0.isCompleted(on: Date()) }
    }
    
    private var completedHabits: [Habit] {
        habits.filter { $0.isCompleted(on: Date()) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Habits")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 4)
            
            if habits.isEmpty {
                Text("No habits yet. Add your first habit!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                if !incompleteHabits.isEmpty {
                    ForEach(incompleteHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: false,
                            isSelected: selectedHabit?.id == habit.id
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
                
                if !completedHabits.isEmpty {
                    Text("Completed Today")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    
                    ForEach(completedHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            isCompleted: true,
                            isSelected: selectedHabit?.id == habit.id
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
