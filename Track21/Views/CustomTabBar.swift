//
//  CustomTabBar.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showingAddHabit: Bool

    var body: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 0 ? .primary : .gray)
            }
            .accessibilityLabel("Home")
            .frame(maxWidth: .infinity)

            Button(action: { selectedTab = 1 }) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 1 ? .primary : .gray)
            }
            .accessibilityLabel("Statistics")
            .frame(maxWidth: .infinity)

            Button(action: { selectedTab = 2 }) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 2 ? .primary : .gray)
            }
            .accessibilityLabel("Buddy")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(AppTheme.tabBarBackground)
    }
}

/// The "+" button, floating clear of the tab bar with a visible gap above
/// it — a separate overlay rather than a member of the bar's own HStack.
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(AppTheme.primary)
                .clipShape(Circle())
                .shadow(color: AppTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Add new habit")
    }
}
