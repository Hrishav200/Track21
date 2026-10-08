//
//  BuddyQuickReplyChips.swift
//  Track21
//
//  Tappable answers under Buddy's latest message (themes, goal suggestion,
//  habit picker). Shared by full Buddy and Buddy Lite.
//

import SwiftUI

struct BuddyQuickReplyChips: View {
    let replies: [BuddyQuickReply]
    let onTap: (BuddyQuickReply) -> Void

    var body: some View {
        BuddyChipFlowLayout(spacing: 8) {
            ForEach(replies) { reply in
                Button {
                    onTap(reply)
                } label: {
                    chipLabel(reply)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reply.label)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chipLabel(_ reply: BuddyQuickReply) -> some View {
        HStack(spacing: 6) {
            if let hex = reply.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 12, height: 12)
            }
            if reply.kind == .suggestion {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
            }
            Text(reply.label)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(reply.kind == .cancel ? .secondary : AppTheme.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(reply.kind == .cancel ? Color(.systemGray5) : AppTheme.primary.opacity(0.12))
        .cornerRadius(16)
    }
}

/// Minimal wrapping row layout (iOS 16+ `Layout`).
struct BuddyChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
