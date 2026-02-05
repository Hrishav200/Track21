//
//  TodayProgressView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct TodayProgressView: View {
    let viewModel: HabitViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if viewModel.todayTotalCount == 0 {
                Text("Add habits to track your progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("You've completed \(viewModel.todayCompletedCount)/\(viewModel.todayTotalCount) habits today")
                    .font(.system(size: 14, weight: .medium))
                
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.todayTotalCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index < viewModel.todayCompletedCount ? Color(hex: "5DD167") : Color.gray.opacity(0.2))
                            .frame(height: 24)
                    }
                }
                
                if viewModel.todayCompletedCount == viewModel.todayTotalCount {
                    Text("🎉 Amazing! All habits completed!")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "5DD167"))
                } else if viewModel.todayCompletedCount > 0 {
                    Text("You're on track! Just \(viewModel.todayTotalCount - viewModel.todayCompletedCount) more to go!")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Start your day by completing a habit!")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .offset(y: -30)
    }
}
