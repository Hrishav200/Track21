//
//  HabitArchiveView.swift
//  Track21
//
//  "Trophy Case" — finished / expired 21-day cycles. View-only: no toggle,
//  no edit. Habits stay in storage & sync; Home just stops listing them.
//

import SwiftUI

struct HabitArchiveView: View {
    @Bindable var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Habit?

    private var archived: [Habit] {
        viewModel.archivedHabits.sorted { lhs, rhs in
            // Victories first, then most recently ended.
            let lv = HabitVictoryLogic.hasCompletedCycle(lhs)
            let rv = HabitVictoryLogic.hasCompletedCycle(rhs)
            if lv != rv { return lv && !rv }
            return lhs.endDate > rhs.endDate
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if archived.isEmpty {
                    ContentUnavailableView(
                        "Trophy Case is empty",
                        systemImage: "trophy",
                        description: Text("Finish a 21-day cycle and it will land here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            headerBlurb
                            ForEach(archived, id: \.id) { habit in
                                Button {
                                    selected = habit
                                } label: {
                                    ArchiveHabitRow(habit: habit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                    .background(AppTheme.background)
                }
            }
            .navigationTitle("Trophy Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { habit in
                ArchiveHabitDetailView(habit: habit, viewModel: viewModel)
            }
        }
    }

    private var headerBlurb: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Finished cycles")
                .font(.title3.weight(.bold))
            Text("These habits are read-only. Relive the journey anytime — editing and daily check-offs live on active cycles only.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

private struct ArchiveHabitRow: View {
    let habit: Habit

    private var isVictory: Bool { HabitVictoryLogic.hasCompletedCycle(habit) }
    private var isPerfect: Bool { HabitVictoryLogic.isPerfectCycle(habit) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.color).opacity(0.25))
                    .frame(width: 48, height: 48)
                Image(systemName: isVictory ? (isPerfect ? "crown.fill" : "trophy.fill") : "archivebox.fill")
                    .foregroundColor(Color(hex: habit.color))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                MiniJourneyStrip(habit: habit)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: habit.color).opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(statusLine)")
    }

    private var statusLine: String {
        let filled = habit.cycleDaysAccounted
        let done = habit.totalCompletions
        let frozen = habit.totalFrozen
        if isPerfect {
            return "Perfect 21 · ended \(formatted(habit.endDate))"
        }
        if isVictory {
            if frozen > 0 {
                return "Completed · \(done) days · \(frozen) freezes"
            }
            return "Completed · \(filled)/21 days"
        }
        // Match the journey strip: filled = completed + frozen in-window.
        if frozen > 0 {
            return "Cycle ended · \(filled)/21 (\(done) done · \(frozen) frozen)"
        }
        return "Cycle ended · \(filled)/21 days"
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

struct ArchiveHabitDetailView: View {
    let habit: Habit
    @Bindable var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    private var isVictory: Bool { HabitVictoryLogic.hasCompletedCycle(habit) }
    private var isPerfect: Bool { HabitVictoryLogic.isPerfectCycle(habit) }
    private var accent: Color { Color(hex: habit.color) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    statsGrid
                    journeySection
                    readOnlyNote
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // Soft-delete only — no edit / toggle surfaces.
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteHabit(habit)
                            dismiss()
                        }
                    } label: {
                        Label("Delete permanently", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: isPerfect ? "crown.fill" : (isVictory ? "trophy.fill" : "flag.checkered"))
                .font(.system(size: 40))
                .foregroundColor(accent)
            Text(heroTitle)
                .font(.title2.weight(.bold))
            Text(habit.goal)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(accent.opacity(0.12))
        .cornerRadius(20)
    }

    private var heroTitle: String {
        if isPerfect { return "Perfect Cycle" }
        if isVictory { return "21 Days Strong" }
        return "Cycle Ended"
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statTile("\(habit.totalCompletions)", "Completed")
            statTile("\(habit.totalFrozen)", "Frozen")
            statTile("\(habit.bestStreak)", "Best streak")
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your 21-day journey")
                .font(.headline)
            MiniJourneyStrip(habit: habit)
                .frame(height: 18)
            HStack {
                Text(rangeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Read only")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
    }

    private var rangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return "\(f.string(from: habit.startDate)) – \(f.string(from: habit.endDate))"
    }

    private var readOnlyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
            Text("This cycle is archived. You can view the journey here, but check-offs and edits are locked. Start a new habit from Home to begin another 21 days.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}
