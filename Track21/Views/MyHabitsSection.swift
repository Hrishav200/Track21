//
//  MyHabitsSection.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct MyHabitsSection: View {
    // Mock data
    let incompleteHabits = [
        MockHabit(name: "Do Exercise", goal: "1h", color: "FFB6A3"),
        MockHabit(name: "Running", goal: "3km", color: "6BB6FF")
    ]
    
    let completedHabits = [
        MockHabit(name: "Study", goal: "2h", color: "5DD167"),
        MockHabit(name: "Meditation", goal: "30min", color: "5DD167")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Habits")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 4)
            
            ForEach(incompleteHabits, id: \.name) { habit in
                HabitCardView(habit: habit, isCompleted: false)
            }
            
            Text("Completed")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            ForEach(completedHabits, id: \.name) { habit in
                HabitCardView(habit: habit, isCompleted: true)
            }
        }
        .offset(y: -30)
    }
}

// MARK: - Mock Data Structure
struct MockHabit {
    let name: String
    let goal: String
    let color: String
}

