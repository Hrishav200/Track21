//
//  JournalEntryDetailView.swift
//  Track21
//
//  Sheet for viewing and editing a past journal entry opened from Memory Lane.
//

import SwiftUI

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onSave: (String, JournalMood?, Int?) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var mood: JournalMood?
    @State private var energy: Int?
    @State private var showingDeleteConfirm = false

    init(
        entry: JournalEntry,
        onSave: @escaping (String, JournalMood?, Int?) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: entry.text)
        _mood = State(initialValue: entry.mood)
        _energy = State(initialValue: entry.energy)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text(entry.mood?.emoji ?? "✍️")
                            .font(.system(size: 36))
                            .frame(width: 56, height: 56)
                            .background(
                                Circle().fill(Color(hex: entry.mood?.tintHex ?? "5DD167").opacity(0.2))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mood")
                            .font(.subheadline.weight(.semibold))
                        MoodPickerView(selectedMood: $mood)
                    }

                    EnergyPickerView(energy: $energy)

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 220)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                        )
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Edit page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(text, mood, energy)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete this page?", isPresented: $showingDeleteConfirm) {
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
        entry: JournalEntry(date: Date(), text: "Good day overall — got a run in before work.", mood: .good, energy: 4),
        onSave: { _, _, _ in },
        onDelete: {}
    )
}
