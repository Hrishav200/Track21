//
//  EmptyHabitsView.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//
import SwiftUI

struct EmptyHabitsView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.primary)
            }
            .accessibilityHidden(true)

            Text("No habits yet")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Tap the + button to add your first habit")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
