//
//  StatsView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct StatsView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text("Stats")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Coming soon...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
