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
            Color(hex: "F5F5F5")
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Stats")
                    .font(.system(size: 32, weight: .bold))
                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
        }
    }
}
