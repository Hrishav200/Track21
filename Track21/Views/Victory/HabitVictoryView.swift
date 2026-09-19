//
//  HabitVictoryView.swift
//  Track21
//
//  Full-screen celebration for finishing a full 21-day habit cycle — the
//  core goal of the whole app, so it gets its own big moment instead of
//  blending into the small achievement-unlock toast used for badges.
//  Presented as a fullScreenCover keyed off HabitViewModel.recentHabitVictory
//  (see HabitVictoryLogic / HabitVictoryService for the "did this just
//  happen, and only once" logic).
//

import SwiftUI
import UIKit
import StoreKit

struct HabitVictoryView: View {
    let habit: Habit
    var onDismiss: () -> Void

    @State private var showContent = false
    @State private var shareImage: UIImage?

    private var isPerfect: Bool { HabitVictoryLogic.isPerfectCycle(habit) }
    private var freezesUsed: Int { habit.totalFrozen }
    private var accentColor: Color { Color(hex: habit.color) }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ConfettiView(baseColor: accentColor)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                Spacer()

                Text("🎉🏆🎊")
                    .font(.system(size: 64))
                    .scaleEffect(showContent ? 1 : 0.4)
                    .opacity(showContent ? 1 : 0)

                VStack(spacing: 10) {
                    Text("21 Days Strong!")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("You completed \u{201C}\(habit.name)\u{201D}")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                statsRow

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview(
                                "21 Days Strong! I completed \(habit.name) \u{1F389}",
                                image: Image(uiImage: shareImage)
                            )
                        ) {
                            Text("Share the Win \u{1F4E4}")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.5), lineWidth: 1))
                                .cornerRadius(16)
                        }
                        .accessibilityLabel("Share the win")
                    }

                    Button(action: onDismiss) {
                        Text("Let's Keep Going \u{1F680}")
                            .font(.headline)
                            .foregroundColor(accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                    .accessibilityLabel("Dismiss celebration")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                showContent = true
            }
            renderShareImage()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            requestReviewIfAppropriate()
        }
    }

    /// Finishing a full 21-day cycle is peak goodwill — the natural moment
    /// to ask for a review rather than interrupting mid-session. The system
    /// throttles this on its own (roughly 3x/year regardless of how often
    /// it's called), and HabitVictoryService already guarantees this screen
    /// only ever appears once per habit, so calling it here isn't spammy.
    private func requestReviewIfAppropriate() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: windowScene)
    }

    /// Snapshots the static HabitVictoryShareCard into a UIImage for the
    /// share sheet. Rendered once up front (not lazily on tap) since it's a
    /// cheap, synchronous SwiftUI-to-image pass with no network/async work —
    /// this way the Share button never has to show a loading state.
    private func renderShareImage() {
        let renderer = ImageRenderer(content: HabitVictoryShareCard(habit: habit))
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statChip(value: "21/21", label: "Days")
            statChip(value: "\(habit.bestStreak)", label: "Best Streak")
            if freezesUsed > 0 {
                statChip(value: "\(freezesUsed)", label: freezesUsed == 1 ? "Freeze Used" : "Freezes Used")
            }
        }
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(minWidth: 72)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }

    private var subtitle: String {
        isPerfect
            ? "A perfect cycle — every single day completed. That's real discipline."
            : "A full cycle finished, freeze protection and all. You showed up when it counted."
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [accentColor, Color.black.opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Confetti

/// A lightweight, dependency-free one-shot confetti burst: a fixed set of
/// colored shapes fall from just above the top edge to just below the
/// bottom edge with randomized position, size, rotation and timing, driven
/// entirely by a single SwiftUI animation (no timers, no particle engine).
private struct ConfettiView: View {
    let baseColor: Color

    @State private var animate = false

    private static let palette: [Color] = [.white, .yellow, .pink, .orange, .mint, .cyan]
    private let pieces: [ConfettiPiece]

    init(baseColor: Color) {
        self.baseColor = baseColor
        self.pieces = (0..<50).map { _ in
            ConfettiPiece(
                xFraction: .random(in: 0...1),
                color: [baseColor] .appending(contentsOf: Self.palette).randomElement() ?? .white,
                size: .random(in: 6...12),
                isCircle: Bool.random(),
                delay: .random(in: 0...0.6),
                duration: .random(in: 1.8...3.0),
                rotationDegrees: .random(in: 180...720)
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    shape(for: piece)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * (piece.isCircle ? 1 : 0.5))
                        .position(
                            x: piece.xFraction * proxy.size.width,
                            y: animate ? proxy.size.height + 40 : -40
                        )
                        .rotationEffect(.degrees(animate ? piece.rotationDegrees : 0))
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
    }

    private func shape(for piece: ConfettiPiece) -> AnyShape {
        piece.isCircle ? AnyShape(Circle()) : AnyShape(Rectangle())
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let xFraction: CGFloat
    let color: Color
    let size: CGFloat
    let isCircle: Bool
    let delay: Double
    let duration: Double
    let rotationDegrees: Double
}

private extension Array {
    func appending(contentsOf other: [Element]) -> [Element] {
        self + other
    }
}

#Preview {
    HabitVictoryView(
        habit: Habit(name: "Drink Water", goal: "8 glasses", color: "5DD167"),
        onDismiss: {}
    )
}
