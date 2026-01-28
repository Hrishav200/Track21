//
//  MyHabitsSection.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct MyHabitsSection: View {
    var viewModel: HabitViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Habits")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 4)
            
            if viewModel.incompleteHabits.isEmpty && viewModel.completedHabits.isEmpty {
                EmptyHabitsView()
            } else {
                ForEach(viewModel.incompleteHabits) { habit in
                    HabitCardView(habit: habit, viewModel: viewModel)
                }
                
                if !viewModel.completedHabits.isEmpty {
                    Text("Completed")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    
                    ForEach(viewModel.completedHabits) { habit in
                        HabitCardView(habit: habit, viewModel: viewModel)
                    }
                }
            }
        }
        .offset(y: -30)
    }
}

