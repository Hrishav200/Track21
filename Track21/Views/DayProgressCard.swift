//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day 5 of 21")
                        .font(.system(size: 20, weight: .bold))
                    Text("Start Date: Jan 15, 2025 | End Date: Feb 5, 2025")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("19 Jan, 2025")
                    .font(.system(size: 14, weight: .medium))
            }
            
            WeeklyCalendarView()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: -50)
    }
}
