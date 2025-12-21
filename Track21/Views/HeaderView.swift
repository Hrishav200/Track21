//
//  HeaderView.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct HeaderView: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "5DD167")
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi John!")
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
            
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(Color(hex: "5DD167"))
                )
                .padding(.top, 60)
                .padding(.trailing, 20)
        }
        .frame(height: 180)
    }
}
