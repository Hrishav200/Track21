//
//  CustomTabBar.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showingAddHabit: Bool

    var body: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 0 ? .primary : .gray)
            }
            .accessibilityLabel("Home")
            .frame(maxWidth: .infinity)

            Button(action: { selectedTab = 1 }) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 1 ? .primary : .gray)
            }
            .accessibilityLabel("Statistics")
            .frame(maxWidth: .infinity)

            Button(action: { selectedTab = 2 }) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundColor(selectedTab == 2 ? .primary : .gray)
            }
            .accessibilityLabel("Buddy")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(AppTheme.tabBarBackground)
    }
}

/// The "+" button, floating clear of the tab bar with a visible gap above
/// it — a separate overlay rather than a member of the bar's own HStack.
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(AppTheme.primary)
                .clipShape(Circle())
                .shadow(color: AppTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Add new habit")
    }
}

/// Wraps FloatingAddButton so it can be dragged anywhere on screen — the
/// chosen spot is remembered (as a fraction of screen size, so it still
/// makes sense if the app runs on a different-sized screen later) and
/// restored on the next launch.
struct DraggableFloatingAddButton: View {
    let action: () -> Void

    @State private var position: CGPoint?
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGSize = .zero

    private let radius: CGFloat = 29
    private let positionKey = "Track21FloatingButtonPosition"

    var body: some View {
        GeometryReader { geo in
            let base = position ?? defaultPosition(in: geo.size)
            let current = CGPoint(x: base.x + dragTranslation.width, y: base.y + dragTranslation.height)

            FloatingAddButton(action: action)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .position(current)
                .gesture(
                    // minimumDistance: 0 — the default 10pt dead zone is what
                    // reads as "lag" before the button starts following your
                    // finger; tracking from the very first touch move feels
                    // instant, closer to AssistiveTouch.
                    DragGesture(minimumDistance: 0)
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { _ in
                            if !isDragging {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                    isDragging = true
                                }
                            }
                        }
                        .onEnded { value in
                            let dropped = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                            let clamped = clamp(dropped, in: geo.size)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                position = clamped
                                isDragging = false
                            }
                            persist(clamped, screenSize: geo.size)
                        }
                )
                .onAppear {
                    if position == nil {
                        position = loadPersistedPosition(screenSize: geo.size) ?? defaultPosition(in: geo.size)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private func defaultPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height - 78 - radius)
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, radius), size.width - radius),
            y: min(max(point.y, radius), size.height - radius)
        )
    }

    private func persist(_ point: CGPoint, screenSize: CGSize) {
        guard screenSize.width > 0, screenSize.height > 0 else { return }
        UserDefaults.standard.set([point.x / screenSize.width, point.y / screenSize.height], forKey: positionKey)
    }

    private func loadPersistedPosition(screenSize: CGSize) -> CGPoint? {
        guard let normalized = UserDefaults.standard.array(forKey: positionKey) as? [Double], normalized.count == 2 else {
            return nil
        }
        return CGPoint(x: normalized[0] * screenSize.width, y: normalized[1] * screenSize.height)
    }
}
