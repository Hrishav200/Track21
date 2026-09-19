//
//  JournalView.swift
//  Track21
//
//  Replaces Achievements as the fourth main tab — a daily reflection
//  (mood + freeform text) alongside the habit grid, rather than a badge
//  grid. Achievements still exist and still unlock in the background
//  (see ContentView's celebration toast); the full badge browser just
//  moved to Profile since it's checked far less often than this is meant
//  to be used.
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
    @State private var selectedEntry: JournalEntry?
    @State private var justSaved = false
    @FocusState private var isEditorFocused: Bool

    private var journalStreak: Int {
        JournalLogic.currentStreak(entries: journalService.entries)
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .edgesIgnoringSafeArea(.all)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        todayCard

                        if journalService.entries.isEmpty {
                            emptyPastState
                        } else {
                            entriesSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 100)
                }
                // .interactively's drag-tracking gesture recognizer is a
                // known culprit for swallowing the first tap on a button
                // right as the keyboard settles — BuddyChatView hit the
                // same text-input-plus-button-in-scrollable-content shape
                // and already settled on .immediately for exactly that
                // reason, so this follows the same precedent.
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: isEditorFocused) { _, isFocused in
                    guard isFocused else { return }
                    // Deferred a tick so the keyboard's safe-area inset has
                    // actually applied before scrolling — scrolling in the
                    // same run-loop pass as the focus change can land short
                    // and leave Save Entry under the keyboard, same fix as
                    // LoginView's focused-field scrolling.
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo("journalSaveButton", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryDetailView(
                entry: entry,
                onSave: { text, mood in
                    journalService.update(id: entry.id, text: text, mood: mood)
                },
                onDelete: {
                    journalService.delete(entry)
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Journal")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.heavy)
            Text("A little reflection goes a long way")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Unlike habits, journal entries aren't synced yet — true
            // regardless of guest vs. signed-in, unlike the guest-only
            // banner on Home, so this can't just ride along with that.
            // Worth saying plainly rather than letting someone lose weeks
            // of entries to a reinstall with no warning it was ever a risk.
            HStack(spacing: 5) {
                Image(systemName: "iphone")
                    .font(.caption2)
                Text("Entries stay on this device — not backed up yet")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if journalStreak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(journalStreak)-day streak")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(20)
                }
            }

            MoodPickerView(selectedMood: $todayMood)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $todayText)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 100)
                    .focused($isEditorFocused)

                if todayText.isEmpty {
                    Text("How did today go?")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(AppTheme.background)
            .cornerRadius(12)

            Button(action: saveToday) {
                HStack(spacing: 6) {
                    if justSaved {
                        Image(systemName: "checkmark")
                    }
                    Text(justSaved ? "Saved" : "Save Entry")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background((justSaved ? Color.green : AppTheme.primary).gradient)
                .cornerRadius(14)
            }
            .disabled(!hasUnsavedContent)
            .opacity(hasUnsavedContent ? 1 : 0.5)
            .id("journalSaveButton")
            .animation(.easeInOut(duration: 0.2), value: justSaved)
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
    }

    /// Every saved entry, today included — shown as a standing record right
    /// below the "Today" composer so saving produces visible, persistent
    /// proof (not just a transient "Saved" flash that fades and leaves the
    /// screen looking exactly like before you wrote anything).
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Entries")
                .font(.system(.headline, design: .rounded))

            VStack(spacing: 4) {
                ForEach(journalService.entries) { entry in
                    entryRow(entry)
                }
            }
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        let isToday = Calendar.current.isDateInToday(entry.date)
        // Multiple entries can share a day now, so today's rows also show a
        // time — otherwise two entries from today would both just say
        // "Today" with no way to tell them apart in the list.
        let dateLabel = isToday
            ? "Today, \(entry.createdAt.formatted(date: .omitted, time: .shortened))"
            : entry.date.formatted(date: .abbreviated, time: .omitted)

        return Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 12) {
                Text(entry.mood?.emoji ?? "📝")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(entry.text.isEmpty ? "No note" : entry.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dateLabel), \(entry.mood?.label ?? "no mood recorded"), \(entry.text.isEmpty ? "no note" : entry.text)")
    }

    private var emptyPastState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
                .accessibilityHidden(true)
            Text("Your entries will show up here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var hasUnsavedContent: Bool {
        !todayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || todayMood != nil
    }

    private func saveToday() {
        journalService.add(text: todayText, mood: todayMood, date: Date(), userId: authService.currentUser?.id)
        isEditorFocused = false

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        justSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            justSaved = false
            // Clear only after the confirmation fades, so the card doesn't
            // blank out from under the user mid-checkmark — ready for a new
            // entry rather than looking like it's still "editing" this one.
            todayText = ""
            todayMood = nil
        }
    }
}

#Preview {
    JournalView(viewModel: HabitViewModel(), authService: AuthService())
}
