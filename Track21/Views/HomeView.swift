//
//  HomeView.swift
//  Track21
//
//  Created by Hrishav Sunar on 13/10/2025.
//

import SwiftUI


struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView()
                
                VStack(spacing: 16) {
                    DayProgressCard()
                    
                    TodayProgressView()
                    
                    MyHabitsSection()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color(hex: "F5F5F5"))
        .edgesIgnoringSafeArea(.top)
    }
}
