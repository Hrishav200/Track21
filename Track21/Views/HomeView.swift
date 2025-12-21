//
//  HomeView.swift
//  Track21
//
//  Created by Hrishav Sunar on 13/10/2025.
//

import SwiftUI

struct HomeView: View {
    var viewModel: HabitViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel)
                
                VStack(spacing: 16) {
                    DayProgressCard(viewModel: viewModel)
                    
                    TodayProgressView(viewModel: viewModel)
                    
                    MyHabitsSection(viewModel: viewModel)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color(hex: "F5F5F5"))
        .edgesIgnoringSafeArea(.top)
    }
}
└── Views/
    ├── ContentView.swift
    ├── HabitListView.swift
    ├── HabitRowView.swift
    ├── AddHabitView.swift
    ├── HabitDetailView.swift
    ├── CalendarGridView.swift
    └── EmptyStateView.swift
