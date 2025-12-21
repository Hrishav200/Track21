//
//  TodayProgressView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct TodayProgressView: View {
    let completed = 3
    let total = 5
    
    var body: some View {
        VStack(spacing: 12) {
            Text("You've completed \(completed)/\(total) habits today")
                .font(.system(size: 14, weight: .medium))
            
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index < completed ? Color(hex: "5DD167") : Color.gray.opacity(0.2))
                        .frame(height: 24)
                }
            }
            
            Text("You're on track! Just \(total - completed) more to go!")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .offset(y: -30)
    }
}

