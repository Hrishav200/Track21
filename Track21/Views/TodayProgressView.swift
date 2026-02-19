//
//  TodayProgressView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct TodayProgressView: View {
    let viewModel: HabitViewModel
    var selectedDate: Date = Date()

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var completedCount: Int {
        viewModel.habits.filter { $0.isCompleted(on: selectedDate) }.count
    }

    private var totalCount: Int {
        viewModel.habits.count
    }

    var body: some View {
        VStack(spacing: 12) {
            if totalCount == 0 {
                Text("Add habits to track your progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("You've completed \(completedCount)/\(totalCount) habits \(isToday ? "today" : "that day")")
                    .font(.subheadline)

                HStack(spacing: 8) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index < completedCount ? AppTheme.primary : Color.gray.opacity(0.2))
                            .frame(height: 24)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(completedCount) of \(totalCount) habits completed")

                if completedCount == totalCount {
                    Text(isToday ? "Amazing! All habits completed!" : "All habits were completed!")
                        .font(.caption)
                        .foregroundColor(AppTheme.primary)
                } else if completedCount > 0 {
                    Text(isToday ? "You're on track! Just \(totalCount - completedCount) more to go!" : "\(totalCount - completedCount) habits were missed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(isToday ? "Start your day by completing a habit!" : "No habits were completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .offset(y: -30)
    }
}
