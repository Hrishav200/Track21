//
//  BuddyActionCard.swift
//  Track21
//
//  Confirmation card shown inline in chat when the AI buddy proposes a
//  habit management action. The user must tap Confirm or Cancel before
//  the action executes.
//

import SwiftUI

struct BuddyActionCard: View {
    let action: BuddyAction
    let status: ActionStatus
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var actionColor: Color {
        switch action.type {
        case .addHabit:
            return AppTheme.primary  // Green
        case .updateHabit:
            return .blue
        case .deleteHabit:
            return .red
        }
    }

    private var actionIcon: String {
        switch action.type {
        case .addHabit:
            return "plus.circle.fill"
        case .updateHabit:
            return "pencil.circle.fill"
        case .deleteHabit:
            return "trash.circle.fill"
        }
    }

    private var actionTitle: String {
        switch action.type {
        case .addHabit:
            return "Add Habit"
        case .updateHabit:
            return "Update Habit"
        case .deleteHabit:
            return "Delete Habit"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: actionIcon)
                    .font(.title2)
                    .foregroundColor(actionColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(action.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if status == .pending {
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
                        Text("Confirm")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(actionColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
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

    private var statusIcon: String {
        switch status {
        case .confirmed, .executed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        case .pending:
            return "hourglass"
        }
    }

    private var statusText: String {
        switch status {
        case .pending:
            return "Awaiting confirmation..."
        case .confirmed:
            return "Confirmed"
        case .cancelled:
            return "Cancelled"
        case .executed:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .confirmed, .executed:
            return AppTheme.primary
        case .cancelled:
            return .secondary
        case .failed:
            return .red
        case .pending:
            return .secondary
        }
    }
}
