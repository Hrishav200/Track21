//
//  AchievementsView.swift
//  Track21
//
//  Grid of badges derived from AchievementService — nothing here decides
//  unlock state itself, it just displays whatever the service computes.
//

import SwiftUI

struct AchievementsView: View {
    @Bindable var viewModel: HabitViewModel
    @State private var achievements: [Achievement] = []
    @State private var selectedAchievement: Achievement?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ZStack {
            AppTheme.background
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(achievements) { achievement in
                            AchievementBadgeCard(achievement: achievement)
                                .onTapGesture { selectedAchievement = achievement }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 100)
            }
        }
        .onAppear { refresh() }
        .onChange(of: viewModel.habits.count) { refresh() }
        .onChange(of: viewModel.lastSyncDate) { refresh() }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailView(achievement: achievement)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Achievements")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("\(achievements.filter(\.isUnlocked).count) of \(achievements.count) unlocked")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func refresh() {
        achievements = AchievementService.shared.refresh(habits: viewModel.habits).all
    }
}

private struct AchievementBadgeCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(achievement.isUnlocked ? AppTheme.primary.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 64, height: 64)

                Text(achievement.emoji)
                    .font(.system(size: 28))
                    .grayscale(achievement.isUnlocked ? 0 : 1)
                    .opacity(achievement.isUnlocked ? 1 : 0.4)
                    .frame(width: 64, height: 64)

                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(achievement.isUnlocked ? "unlocked" : "locked")")
    }
}

private struct AchievementDetailView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(achievement.emoji)
                    .font(.system(size: 64))
                    .grayscale(achievement.isUnlocked ? 0 : 1)
                    .opacity(achievement.isUnlocked ? 1 : 0.5)
                    .padding(.top, 32)

                Text(achievement.title)
                    .font(.title2.weight(.bold))

                Text(achievement.isUnlocked ? achievement.unlockedDescription : achievement.lockedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if achievement.isUnlocked, let date = achievement.unlockedDate {
                    Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ProgressView(value: achievement.progress)
                            .tint(AppTheme.primary)
                        Text("\(achievement.progressCurrent)/\(achievement.progressTarget)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 48)
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AchievementsView(viewModel: HabitViewModel())
}
