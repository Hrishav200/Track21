//
//  ChatHistoryView.swift
//  Track21
//
//  Browsable list of past chat conversations. Users can tap to resume a
//  conversation or start a new one.
//

import SwiftUI

struct ChatHistoryView: View {
    @Bindable var buddyService: BuddyService
    let onSelectConversation: (ChatConversation) -> Void
    @Environment(\.dismiss) private var dismiss

    private var sortedConversations: [ChatConversation] {
        buddyService.conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    var body: some View {
        NavigationView {
            Group {
                if sortedConversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var conversationList: some View {
        List {
            ForEach(sortedConversations) { conversation in
                Button {
                    onSelectConversation(conversation)
                } label: {
                    ChatHistoryRow(
                        conversation: conversation,
                        isActive: conversation.id == buddyService.activeConversationID
                    )
                }
                .listRowBackground(AppTheme.cardBackground)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            Text("No conversations yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Start chatting with your buddy to see your history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ChatHistoryRow: View {
    let conversation: ChatConversation
    let isActive: Bool

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.lastMessageAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.buddyName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if isActive {
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary)
                            .cornerRadius(4)
                    }
                }
                Text(conversation.truncatedPreview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(conversation.messages.count) messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    ChatHistoryView(buddyService: BuddyService.shared) { _ in }
}
