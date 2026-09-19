//
//  MoodPickerView.swift
//  Track21
//
//  Shared mood-selector row — used by both JournalView's always-visible
//  "Today" composer and JournalEntryDetailView's edit sheet for a past day.
//

import SwiftUI

struct MoodPickerView: View {
    @Binding var selectedMood: JournalMood?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(JournalMood.allCases) { mood in
                moodButton(mood)
            }
        }
    }

    private func moodButton(_ mood: JournalMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedMood = isSelected ? nil : mood
            }
        } label: {
            Text(mood.emoji)
                .font(.system(size: isSelected ? 28 : 22))
                .frame(width: 44, height: 44)
                .background(isSelected ? AppTheme.primary.opacity(0.15) : Color.gray.opacity(0.08))
                .clipShape(Circle())
                .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    MoodPickerView(selectedMood: .constant(.good))
        .padding()
        .background(AppTheme.background)
}
