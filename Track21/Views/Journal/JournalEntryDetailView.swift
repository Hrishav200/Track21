//
//  JournalEntryDetailView.swift
//  Track21
//
//  Sheet for viewing and editing a past day's journal entry. Today's entry
//  is edited inline on JournalView itself — this is only reached by
//  tapping a day in the "Past Entries" list.
//

import SwiftUI

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onSave: (String, JournalMood?) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var mood: JournalMood?
    @State private var showingDeleteConfirm = false

    init(entry: JournalEntry, onSave: @escaping (String, JournalMood?) -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: entry.text)
        _mood = State(initialValue: entry.mood)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                MoodPickerView(selectedMood: $mood)

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .frame(minHeight: 200)

                Spacer(minLength: 0)
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(text, mood)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete this entry?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

#Preview {
    JournalEntryDetailView(
        entry: JournalEntry(date: Date(), text: "Good day overall — got a run in before work.", mood: .good),
        onSave: { _, _ in },
        onDelete: {}
    )
}
