//
//  BuddyActionCard.swift
//  Track21
//
//  Confirmation card shown inline in chat when Buddy proposes adding or
//  editing a habit. Nothing changes until the user taps Add/Save.
//

import SwiftUI

struct BuddyActionCard: View {
    let action: BuddyAction
    let status: ActionStatus
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var actionColor: Color {
        switch action.type {
        case .addHabit: return AppTheme.primary
        case .updateHabit: return .blue
        case .deleteHabit: return .red
        }
    }

    private var actionIcon: String {
        switch action.type {
        case .addHabit: return "plus.circle.fill"
        case .updateHabit: return "pencil.circle.fill"
        case .deleteHabit: return "trash.circle.fill"
        }
    }

    private var actionTitle: String {
        switch action.type {
        case .addHabit: return "New habit"
        case .updateHabit: return "Edit habit"
        case .deleteHabit: return "Delete habit"
        }
    }

    private var confirmTitle: String {
        action.type == .addHabit ? "Add" : "Save"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: actionIcon)
                    .font(.title2)
                    .foregroundColor(actionColor)
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            if action.type == .deleteHabit {
                Text(action.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Name") {
                        Text(nameText)
                    }
                    detailRow("Theme") {
                        if let hex = action.habitColor {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 12, height: 12)
                                Text(HabitTheme.name(forHex: hex))
                            }
                        } else {
                            Text("Unchanged").foregroundColor(.secondary)
                        }
                    }
                    detailRow("Goal") {
                        Text(action.habitGoal ?? "Unchanged")
                    }
                }
            }

            if status == .pending {
                if action.type == .deleteHabit {
                    // Deleting from chat isn't supported (old history only).
                    Text("Deleting from chat isn\u{2019}t supported. Long-press the habit on Home instead.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: onCancel) {
                        Text("Dismiss")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                } else {
                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }

                        Button(action: onConfirm) {
                            Text(confirmTitle)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(actionColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel(confirmTitle == "Add" ? "Add habit" : "Save habit changes")
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(statusText)
                        .font(.caption)
                }
                .foregroundColor(statusColor)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(actionColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var nameText: String {
        if action.type == .updateHabit, let newName = action.newHabitName, newName != action.habitName {
            return "\(action.habitName) \u{2192} \(newName)"
        }
        return action.habitName
    }

    private func detailRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .leading)
            content()
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var statusIcon: String {
        switch status {
        case .confirmed, .executed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .pending: return "hourglass"
        }
    }

    private var statusText: String {
        switch status {
        case .pending: return "Awaiting confirmation..."
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .executed: return action.type == .addHabit ? "Added" : "Saved"
        case .failed: return "Not changed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .confirmed, .executed: return AppTheme.primary
        case .cancelled, .pending: return .secondary
        case .failed: return .red
        }
    }
}
