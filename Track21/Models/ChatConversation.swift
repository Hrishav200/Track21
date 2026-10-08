//
//  ChatConversation.swift
//  Track21
//
//  Data models for persisted chat history. ChatMessage represents a single
//  message in a conversation, ChatConversation groups messages into sessions
//  that users can browse and resume.
//

import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let isFromUser: Bool
    let text: String
    let timestamp: Date
    var pendingAction: BuddyAction?
    var actionStatus: ActionStatus?
    /// Tappable answers offered under a Buddy message (theme chips, goal
    /// suggestion, habit picker…). Optional so older history still decodes.
    var quickReplies: [BuddyQuickReply]?

    init(
        id: UUID = UUID(),
        isFromUser: Bool,
        text: String,
        timestamp: Date = Date(),
        pendingAction: BuddyAction? = nil,
        actionStatus: ActionStatus? = nil,
        quickReplies: [BuddyQuickReply]? = nil
    ) {
        self.id = id
        self.isFromUser = isFromUser
        self.text = text
        self.timestamp = timestamp
        self.pendingAction = pendingAction
        self.actionStatus = actionStatus
        self.quickReplies = quickReplies
    }
}

/// A one-tap reply chip under a Buddy message. Tapping sends `value` as the
/// user's next message.
struct BuddyQuickReply: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case option
        case suggestion
        case cancel
    }

    let label: String
    let value: String
    /// Theme/habit colour dot shown on the chip.
    var colorHex: String?
    var kind: Kind

    var id: String { "\(kind.rawValue)|\(label)" }

    init(label: String, value: String, colorHex: String? = nil, kind: Kind = .option) {
        self.label = label
        self.value = value
        self.colorHex = colorHex
        self.kind = kind
    }
}

struct ChatConversation: Codable, Identifiable, Equatable {
    let id: UUID
    let buddyName: String
    let createdAt: Date
    var messages: [ChatMessage]
    var lastMessageAt: Date

    init(id: UUID = UUID(), buddyName: String, createdAt: Date = Date(), messages: [ChatMessage] = []) {
        self.id = id
        self.buddyName = buddyName
        self.createdAt = createdAt
        self.messages = messages
        self.lastMessageAt = messages.last?.timestamp ?? createdAt
    }

    /// Preview text for the history list (first user message or buddy greeting)
    var previewText: String {
        messages.first(where: { $0.isFromUser })?.text
            ?? messages.first?.text
            ?? "New conversation"
    }

    /// Truncated preview for display in history list
    var truncatedPreview: String {
        let preview = previewText
        return preview.count > 60 ? String(preview.prefix(60)) + "..." : preview
    }
}
