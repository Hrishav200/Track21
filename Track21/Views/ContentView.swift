//
//  ContentView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//


import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                StatsView()
                    .tag(1)
            }
            
            CustomTabBar(selectedTab: $selectedTab)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

