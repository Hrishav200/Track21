//
//  HabitVictoryShareCard.swift
//  Track21
//
//  A static, portrait-oriented version of the victory celebration — no
//  animation, no buttons — purpose-built to be rendered off-screen into a
//  UIImage (via ImageRenderer, see HabitVictoryView.renderShareImage) and
//  handed to the system share sheet. Instagram Stories, WhatsApp Status,
//  Facebook and Messages all register as image-sharing targets there, so a
//  plain ShareLink with this image covers every platform the user asked
//  for without any per-network SDK. Fixed 3:5-ish portrait size mirrors an
//  Instagram Story canvas so it drops in without letterboxing.
//

import SwiftUI

struct HabitVictoryShareCard: View {
    let habit: Habit

    private var isPerfect: Bool { HabitVictoryLogic.isPerfectCycle(habit) }
    private var freezesUsed: Int { habit.totalFrozen }
    private var accentColor: Color { Color(hex: habit.color) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor, Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 22) {
                Spacer()

                Text("🎉🏆🎊")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("21 Days Strong!")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("I completed \u{201C}\(habit.name)\u{201D}")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }

                HStack(spacing: 16) {
                    statChip(value: "21/21", label: "Days")
                    statChip(value: "\(habit.bestStreak)", label: "Best Streak")
                    if freezesUsed > 0 {
                        statChip(value: "\(freezesUsed)", label: freezesUsed == 1 ? "Freeze Used" : "Freezes Used")
                    }
                }

                Text(isPerfect
                     ? "A perfect cycle — every single day completed."
                     : "A full cycle finished, freeze protection and all.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Tracked with Track21")
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 36)
            }
        }
        .frame(width: 400, height: 700)
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
}

#Preview {
    HabitVictoryShareCard(habit: Habit(name: "Drink Water", goal: "8 glasses", color: "5DD167"))
}
