//
//  EmptyHabitsView.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//
import SwiftUI

struct EmptyHabitsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)

            Text("No habits yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tap the + button to add your first habit")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
