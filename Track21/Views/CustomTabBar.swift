//
//  CustomTabBar.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 24))
                    .foregroundColor(selectedTab == 0 ? .black : .gray)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                // Add habit action - will implement later
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "5DD167"))
                    .clipShape(Circle())
            }
            .offset(y: -20)
            
            Button(action: { selectedTab = 1 }) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 24))
                    .foregroundColor(selectedTab == 1 ? .black : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(Color.white)
    }
}
