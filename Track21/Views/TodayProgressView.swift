//
//  TodayProgressView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct TodayProgressView: View {
    let habits: [Habit]
    
    private var completed: Int {
        habits.filter { $0.isCompleted(on: Date()) }.count
    }
    
    private var total: Int {
        habits.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if total == 0 {
                Text("Add habits to track your progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("You've completed \(completed)/\(total) habits today")
                    .font(.system(size: 14, weight: .medium))
                
                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index < completed ? Color(hex: "5DD167") : Color.gray.opacity(0.2))
                            .frame(height: 24)
                    }
                }
                
                if completed == total {
                    Text("🎉 Amazing! All habits completed!")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "5DD167"))
                } else if completed > 0 {
                    Text("You're on track! Just \(total - completed) more to go!")
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
