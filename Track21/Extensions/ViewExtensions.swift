//
//  ViewExtensions.swift
//  Track21
//
//  Shared view modifiers for a consistent "premium" elevated-card look
//  across the Stats tab — a soft shadow + hairline edge instead of the
//  flat `.background(...).cornerRadius(...)` every stats card used to
//  hand-roll individually.
//

import SwiftUI

extension View {
    /// The Stats tab's elevated card surface: rounded background, a soft
    /// drop shadow for depth, and a faint top-edge highlight that reads as
    /// a subtle sheen in light mode without needing an image asset.
    func statsCardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}
