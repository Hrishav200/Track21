//
//  BuddyHabitActionCoordinator.swift
//  Track21
//
//  Glue between Buddy's chat UI and BuddyHabitFlow, shared by full Buddy
//  and Buddy Lite: posts flow replies, and runs a proposal only when its
//  card is confirmed (once), then syncs like the Add/Edit screens do.
//

import Foundation

enum BuddyHabitActionCoordinator {

    /// Appends Buddy's flow reply (text + chips + optional confirmation card).
    static func post(_ reply: BuddyHabitFlowReply, to buddyService: BuddyService) {
        buddyService.appendMessage(ChatMessage(
            isFromUser: false,
            text: reply.text,
            pendingAction: reply.proposal,
            actionStatus: reply.proposal != nil ? .pending : nil,
            quickReplies: reply.quickReplies.isEmpty ? nil : reply.quickReplies
        ))
    }

    static func confirm(
        messageID: UUID,
        action: BuddyAction,
        buddyService: BuddyService,
        viewModel: HabitViewModel,
        userId: UUID?
    ) {
        // Guard against double taps / re-confirming an old card.
        let current = buddyService.activeConversation?.messages.first { $0.id == messageID }?.actionStatus
        guard current == nil || current == .pending else { return }

        buddyService.updateMessageActionStatus(messageID: messageID, status: .confirmed)
        let outcome = BuddyHabitActionExecutor.execute(
            action,
            status: .confirmed,
            store: viewModel,
            userId: userId
        )
        buddyService.updateMessageActionStatus(messageID: messageID, status: outcome.succeeded ? .executed : .failed)
        buddyService.appendMessage(ChatMessage(
            isFromUser: false,
            text: BuddyHabitActionExecutor.followUpText(for: action, outcome: outcome)
        ))

        // Same post-save sync as AddHabitView / EditHabitView.
        if outcome.succeeded, let userId {
            Task {
                await viewModel.syncWithCloud(userId: userId)
            }
        }
    }

    static func cancel(messageID: UUID, buddyService: BuddyService) {
        let current = buddyService.activeConversation?.messages.first { $0.id == messageID }?.actionStatus
        guard current == nil || current == .pending else { return }
        buddyService.updateMessageActionStatus(messageID: messageID, status: .cancelled)
        buddyService.appendMessage(ChatMessage(
            isFromUser: false,
            text: "No problem, nothing changed."
        ))
    }
}
