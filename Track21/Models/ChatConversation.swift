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

    init(id: UUID = UUID(), isFromUser: Bool, text: String, timestamp: Date = Date()) {
        self.id = id
        self.isFromUser = isFromUser
        self.text = text
        self.timestamp = timestamp
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
