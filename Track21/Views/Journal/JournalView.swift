//
//  JournalView.swift
//  Track21
//
//  Daily reflection ritual — mood, energy, habit-aware prompts, and a
//  Memory Lane timeline. Designed to feel addictive to open and satisfying
//  to save, without fighting the rest of Track 21's green language.
//

import SwiftUI
import UIKit
internal import Auth

struct JournalView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService

    @State private var journalService = JournalService.shared
    @State private var todayText: String = ""
    @State private var todayMood: JournalMood?
    @State private var todayEnergy: Int?
    @State private var selectedEntry: JournalEntry?
    @State private var justSaved = false
    @State private var showSaveBurst = false
    @State private var promptSeed = Int.random(in: 0...10_000)
    @FocusState private var isEditorFocused: Bool

    private var journalStreak: Int {
        JournalLogic.currentStreak(entries: journalService.entries)
    }

    private var dayCount: Int {
        JournalLogic.uniqueDayCount(entries: journalService.entries)
    }

    private var activePrompt: String {
        JournalPrompts.prompt(
            habits: viewModel.activeHabits,
            streak: journalStreak,
            seed: promptSeed
        )
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            // Soft brand wash behind the header — tasteful depth, not a full gradient screen.
            LinearGradient(
                colors: [AppTheme.primary.opacity(0.18), AppTheme.primary.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        heroHeader
                        streakRibbon
                        composerCard

                        if journalService.entries.isEmpty {
                            emptyState
                        } else {
                            memoryLane
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                    .padding(.bottom, 110)
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: isEditorFocused) { _, isFocused in
                    guard isFocused else { return }
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo("journalSaveButton", anchor: .bottom)
                        }
                    }
                }
            }

            if showSaveBurst {
                saveBurstOverlay
                    .transition(.opacity)
                    .zIndex(2)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryDetailView(
                entry: entry,
                onSave: { text, mood, energy in
                    journalService.update(id: entry.id, text: text, mood: mood, energy: energy)
                },
                onDelete: {
                    journalService.delete(entry)
                }
            )
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(JournalPrompts.greeting())
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("Journal")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                    Text("Your 21-day story, one honest page at a time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    statChip(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: "\(journalStreak)",
                        label: "streak"
                    )
                    statChip(
                        icon: "book.closed.fill",
                        iconColor: AppTheme.primary,
                        value: "\(dayCount)",
                        label: dayCount == 1 ? "day" : "days"
                    )
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "iphone")
                    .font(.caption2)
                Text("Entries stay on this device — not backed up yet")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }

    private func statChip(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundColor(iconColor)
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.cardBackground.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Streak ribbon

    private var streakRibbon: some View {
        let marks = JournalLogic.weekRibbon(entries: journalService.entries)
        return VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 0) {
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    VStack(spacing: 6) {
                        Text(shortWeekday(mark.date))
                            .font(.caption2.weight(mark.isToday ? .bold : .medium))
                            .foregroundColor(mark.isToday ? AppTheme.primary : .secondary)

                        ZStack {
                            Circle()
                                .stroke(
                                    mark.isToday ? AppTheme.primary : Color.gray.opacity(0.25),
                                    lineWidth: mark.isToday ? 2 : 1
                                )
                                .frame(width: 30, height: 30)

                            if mark.hasEntry {
                                Circle()
                                    .fill(AppTheme.primary.gradient)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            } else if mark.isToday {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.15))
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .statsCardStyle(cornerRadius: 18)
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(2))
    }

    // MARK: - Composer

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's page")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if hasUnsavedContent {
                    Text("Draft")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            promptBanner

            VStack(alignment: .leading, spacing: 6) {
                Text("Mood")
                    .font(.subheadline.weight(.semibold))
                MoodPickerView(selectedMood: $todayMood)
            }

            EnergyPickerView(energy: $todayEnergy)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $todayText)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 120)
                    .focused($isEditorFocused)

                if todayText.isEmpty {
                    Text("Write freely — messy is perfect.")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isEditorFocused ? AppTheme.primary.opacity(0.45) : Color.gray.opacity(0.12),
                        lineWidth: isEditorFocused ? 1.5 : 1
                    )
            )

            Button(action: saveToday) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            (justSaved ? Color.green : AppTheme.primary).gradient
                        )
                        .shadow(
                            color: (justSaved ? Color.green : AppTheme.primary).opacity(hasUnsavedContent ? 0.35 : 0),
                            radius: 12,
                            y: 6
                        )

                    HStack(spacing: 8) {
                        if justSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolEffect(.bounce, value: justSaved)
                        } else {
                            Image(systemName: "square.and.pencil")
                        }
                        Text(justSaved ? "Page saved" : "Save page")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                }
            }
            .disabled(!hasUnsavedContent || justSaved)
            .opacity(hasUnsavedContent || justSaved ? 1 : 0.45)
            .id("journalSaveButton")
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: justSaved)
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 22)
    }

    private var promptBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundColor(AppTheme.primary)
                .padding(.top, 2)

            Text(activePrompt)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    promptSeed &+= 1
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.primary)
                    .padding(8)
                    .background(AppTheme.primary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle prompt")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Memory Lane

    private var memoryLane: some View {
        let sections = JournalLogic.timelineSections(entries: journalService.entries)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Memory Lane")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
                Text("\(journalService.entries.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach(section.entries) { entry in
                            timelineRow(entry)
                        }
                    }
                }
            }
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 22)
    }

    private func timelineRow(_ entry: JournalEntry) -> some View {
        let tint = Color(hex: entry.mood?.tintHex ?? "5DD167")
        let timeLabel = entry.createdAt.formatted(date: .omitted, time: .shortened)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedEntry = entry
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(entry.mood?.emoji ?? "✍️")
                            .font(.title3)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(timeLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        if let energy = entry.energy {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { level in
                                    Image(systemName: level <= energy ? "leaf.fill" : "leaf")
                                        .font(.system(size: 8))
                                        .foregroundColor(level <= energy ? AppTheme.primary : Color.gray.opacity(0.35))
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }

                    Text(entry.text.isEmpty ? "No note — mood only" : entry.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timelineAccessibility(entry, timeLabel: timeLabel))
    }

    private func timelineAccessibility(_ entry: JournalEntry, timeLabel: String) -> String {
        let mood = entry.mood?.label ?? "no mood"
        let note = entry.text.isEmpty ? "no note" : entry.text
        return "\(timeLabel), \(mood), \(note)"
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("Your first page is waiting")
                .font(.system(.title3, design: .rounded).weight(.bold))

            Text("A mood, a line, a leaf of energy — that's enough. Memory Lane grows from here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                isEditorFocused = true
            } label: {
                Text("Start writing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary.gradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 18)
        .statsCardStyle(cornerRadius: 22)
    }

    // MARK: - Save burst

    private var saveBurstOverlay: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.primary.gradient)
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 16)
                Text("Page turned")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .scaleEffect(showSaveBurst ? 1 : 0.85)
        }
    }

    // MARK: - Actions

    private var hasUnsavedContent: Bool {
        !todayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || todayMood != nil
            || todayEnergy != nil
    }

    private func saveToday() {
        journalService.add(
            text: todayText,
            mood: todayMood,
            energy: todayEnergy,
            date: Date(),
            userId: authService.currentUser?.id
        )
        isEditorFocused = false

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            justSaved = true
            showSaveBurst = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                showSaveBurst = false
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            justSaved = false
            todayText = ""
            todayMood = nil
            todayEnergy = nil
            promptSeed &+= 1
        }
    }
}

#Preview {
    JournalView(viewModel: HabitViewModel(), authService: AuthService())
}
