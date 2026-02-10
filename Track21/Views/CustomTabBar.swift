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

            Button(action: { showingAddHabit = true }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.primary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add new habit")
            .offset(y: -20)

            Button(action: { selectedTab = 1 }) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 1 ? .primary : .gray)
            }
            .accessibilityLabel("Statistics")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(AppTheme.tabBarBackground)
    }
}
