//
//  HeaderView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct HeaderView: View {
    var viewModel: HabitViewModel
    var onProfileTap: () -> Void = {}
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "5DD167")
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi \(viewModel.userName)!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Let's build habits today!")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 80)
            
            // Profile button
            Button(action: onProfileTap) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "5DD167"))
                    )
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .frame(height: 180)
    }
    
    private var initials: String {
        let name = viewModel.userName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}
