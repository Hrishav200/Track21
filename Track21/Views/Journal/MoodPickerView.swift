//
//  MoodPickerView.swift
//  Track21
//
//  Expressive mood + energy pickers for the Journal composer and detail
//  sheet. Mood is the emotional tone; energy is the body-budget (1…5).
//

import SwiftUI

struct MoodPickerView: View {
    @Binding var selectedMood: JournalMood?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ForEach(JournalMood.allCases) { mood in
                moodButton(mood)
            }
        }
    }

    private func moodButton(_ mood: JournalMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                selectedMood = isSelected ? nil : mood
            }
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: isSelected ? (compact ? 26 : 30) : (compact ? 20 : 24)))
                    .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                    .background(
                        Circle()
                            .fill(isSelected ? Color(hex: mood.tintHex).opacity(0.22) : Color.gray.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color(hex: mood.tintHex).opacity(0.55) : Color.clear, lineWidth: 2)
                    )
                    .scaleEffect(isSelected ? 1.08 : 1.0)

                if !compact {
                    Text(mood.label)
                        .font(.caption2.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Five-segment energy meter — leaf-tinted to stay on-brand with Track 21 green.
struct EnergyPickerView: View {
    @Binding var energy: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Energy")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(energyLabel)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                            energy = (energy == level) ? nil : level
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fill(for: level))
                            .frame(height: 28)
                            .overlay(
                                Image(systemName: level <= (energy ?? 0) ? "leaf.fill" : "leaf")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(level <= (energy ?? 0) ? .white : AppTheme.primary.opacity(0.45))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Energy \(level) of 5")
                    .accessibilityAddTraits(energy == level ? [.isSelected] : [])
                }
            }
        }
    }

    private var energyLabel: String {
        switch energy {
        case 1: return "Drained"
        case 2: return "Low"
        case 3: return "Steady"
        case 4: return "Good"
        case 5: return "Electric"
        default: return "Optional"
        }
    }

    private func fill(for level: Int) -> Color {
        let selected = energy ?? 0
        if level <= selected {
            return AppTheme.primary.opacity(0.55 + Double(level) * 0.08)
        }
        return Color.gray.opacity(0.1)
    }
}

#Preview {
    VStack(spacing: 24) {
        MoodPickerView(selectedMood: .constant(.good))
        EnergyPickerView(energy: .constant(3))
    }
    .padding()
    .background(AppTheme.background)
}
