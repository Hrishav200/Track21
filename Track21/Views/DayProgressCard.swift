//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    var viewModel: HabitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let firstHabit = viewModel.habits.first {
                        Text("Day \(firstHabit.currentDay) of 21")
                            .font(.system(size: 20, weight: .bold))
                        Text("Start Date: \(firstHabit.startDate, style: .date) | End Date: \(firstHabit.endDate, style: .date)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No habits yet")
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                
                Spacer()
                
                Text(Date(), style: .date)
                    .font(.system(size: 14, weight: .medium))
            }
            
            WeeklyCalendarView(viewModel: viewModel)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: -50)
    }
}
