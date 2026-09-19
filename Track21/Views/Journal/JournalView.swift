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
internal import Auth

struct JournalView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService

    @State private var journalService = JournalService.shared
    @State private var todayText: String = ""
    @State private var todayMood: JournalMood?
    @State private var selectedEntry: JournalEntry?
    @FocusState private var isEditorFocused: Bool

    private var pastEntries: [JournalEntry] {
        journalService.entries.filter { !Calendar.current.isDateInToday($0.date) }
    }

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

                        if pastEntries.isEmpty {
                            emptyPastState
                        } else {
                            pastEntriesSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
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
        .onAppear(perform: loadToday)
        .sheet(item: $selectedEntry) { entry in
            JournalEntryDetailView(
                entry: entry,
                onSave: { text, mood in
                    journalService.save(text: text, mood: mood, for: entry.date, userId: authService.currentUser?.id)
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
                Text("Save Entry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary.gradient)
                    .cornerRadius(14)
            }
            .disabled(!hasUnsavedContent)
            .opacity(hasUnsavedContent ? 1 : 0.5)
            .id("journalSaveButton")
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
    }

    private var pastEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Entries")
                .font(.system(.headline, design: .rounded))

            VStack(spacing: 4) {
                ForEach(pastEntries) { entry in
                    pastEntryRow(entry)
                }
            }
        }
        .padding(18)
        .statsCardStyle(cornerRadius: 20)
    }

    private func pastEntryRow(_ entry: JournalEntry) -> some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 12) {
                Text(entry.mood?.emoji ?? "📝")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
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
        .accessibilityLabel("\(entry.date.formatted(date: .abbreviated, time: .omitted)), \(entry.mood?.label ?? "no mood recorded"), \(entry.text.isEmpty ? "no note" : entry.text)")
    }

    private var emptyPastState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
                .accessibilityHidden(true)
            Text("Your past entries will show up here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var hasUnsavedContent: Bool {
        !todayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || todayMood != nil
    }

    private func loadToday() {
        guard let existing = journalService.todaysEntry else { return }
        todayText = existing.text
        todayMood = existing.mood
    }

    private func saveToday() {
        journalService.save(text: todayText, mood: todayMood, for: Date(), userId: authService.currentUser?.id)
        isEditorFocused = false
    }
}

#Preview {
    JournalView(viewModel: HabitViewModel(), authService: AuthService())
}
