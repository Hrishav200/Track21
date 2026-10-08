//
//  BuddyLiteChatView.swift
//  Track21
//
//  Local habit-aware coaching when Apple Foundation Models aren't available.
//  Same chat chrome as full Buddy — templates from BuddyLogic, no network,
//  no API keys. Soft CTA when the device could run full Buddy but AI is off.
//

import SwiftUI
import UIKit
internal import Auth

struct BuddyLiteChatView: View {
    let buddyName: String
    @Bindable var viewModel: HabitViewModel
    let availabilityReason: BuddyAvailability
    var isTabActive: Bool = true
    /// Used for the signed-in user id when Buddy adds a habit (same as AddHabitView).
    var authService: AuthService? = nil

    @State private var inputText = ""
    @State private var isThinking = false
    @State private var inputFieldID = UUID()
    @FocusState private var isInputFocused: Bool
    /// False while the user has scrolled up to read history.
    @State private var isNearBottom = true
    @State private var buddyService = BuddyService.shared
    @State private var premiumService = PremiumService.shared
    @State private var showingPaywall = false
    @State private var showingHistory = false
    @Environment(\.openURL) private var openURL
    /// Guided add/edit-habit conversation shared with full Buddy.
    @State private var habitFlow = BuddyHabitFlowState()

    private var messages: [ChatMessage] {
        buddyService.activeConversation?.messages ?? []
    }

    private var remainingMessages: Int? {
        BuddyChatUsageLogic.remainingMessages(
            sentToday: buddyService.messagesSentToday,
            isPremium: premiumService.isPremium
        )
    }

    private var softCTA: String? {
        BuddyLogic.liteSoftCTA(for: availabilityReason)
    }

    private var showQuickPrompts: Bool {
        messages.filter(\.isFromUser).isEmpty && !isThinking
    }

    private func shouldStartNewConversation() -> Bool {
        guard let active = buddyService.activeConversation else { return true }
        guard let lastMessage = active.messages.last else { return true }
        return Date().timeIntervalSince(lastMessage.timestamp) > 4 * 60 * 60
    }

    var body: some View {
        VStack(spacing: 0) {
            liteBanner

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                BuddyChatBubble(message: message)

                                if let action = message.pendingAction {
                                    BuddyActionCard(
                                        action: action,
                                        status: message.actionStatus ?? .pending,
                                        onConfirm: {
                                            BuddyHabitActionCoordinator.confirm(
                                                messageID: message.id,
                                                action: action,
                                                buddyService: buddyService,
                                                viewModel: viewModel,
                                                userId: authService?.currentUser?.id
                                            )
                                        },
                                        onCancel: {
                                            BuddyHabitActionCoordinator.cancel(messageID: message.id, buddyService: buddyService)
                                        }
                                    )
                                    .padding(.leading, 4)
                                }

                                if let replies = message.quickReplies, !replies.isEmpty,
                                   !message.isFromUser, message.id == messages.last?.id, !isThinking {
                                    BuddyQuickReplyChips(replies: replies) { reply in
                                        send(reply.value)
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                            .id(message.id)
                        }

                        if isThinking {
                            HStack {
                                ProgressView()
                                    .padding(.leading, 4)
                                Spacer()
                            }
                        }

                        if showQuickPrompts {
                            quickPrompts
                                .padding(.top, 4)
                        }

                        // Always-empty anchor: scrolling to it (rather than to a
                        // bubble that may not be measured yet) reaches the true
                        // bottom, and its visibility tracks "reading near bottom".
                        BuddyChatBottomAnchor(isNearBottom: $isNearBottom)
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture { isInputFocused = false }
                .buddyChatAutoScroll(
                    proxy: proxy,
                    signature: BuddyChatScrollSignature(messages: messages, isThinking: isThinking),
                    isNearBottom: $isNearBottom,
                    isInputFocused: isInputFocused
                )
            }

            Divider()

            if let remaining = remainingMessages, remaining <= 2 {
                Button {
                    showingPaywall = true
                } label: {
                    Text(remaining == 0
                         ? "You're out of messages for today — go Pro for unlimited chat"
                         : "\(remaining) message\(remaining == 1 ? "" : "s") left today — go Pro for unlimited chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }
            }

            HStack(spacing: 12) {
                TextField("Message \(buddyName)...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(18)
                    .accessibilityLabel("Buddy Lite chat message")
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .id(inputFieldID)

                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .gray : AppTheme.primary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                .accessibilityLabel("Send message")
            }
            .padding()
        }
        .onChange(of: isTabActive) { _, active in
            guard !active else { return }
            isInputFocused = false
            BuddyKeyboard.dismiss()
        }
        .onDisappear {
            // Only dismiss when this tab is already inactive. Keyboard/layout
            // transitions can briefly tear the view down while the user types.
            guard !isTabActive else { return }
            isInputFocused = false
            BuddyKeyboard.dismiss()
        }
        .onAppear {
            if buddyService.activeConversation == nil || shouldStartNewConversation() {
                startLiteConversation()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Chat history")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startLiteConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New conversation")
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(trigger: .chatCapped)
        }
        .sheet(isPresented: $showingHistory) {
            ChatHistoryView(buddyService: buddyService) { conversation in
                buddyService.resumeConversation(conversation)
                showingHistory = false
            }
        }
    }

    private var liteBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(AppTheme.primary)
                Text(BuddyLogic.liteModeCaption(for: availabilityReason))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let softCTA {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppTheme.primary)
                        Text(softCTA)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(AppTheme.primary.opacity(0.12))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Settings for Apple Intelligence")
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var quickPrompts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            FlexiblePromptWrap(prompts: BuddyLogic.liteQuickPrompts) { prompt in
                inputText = prompt
                send()
            }
        }
    }

    private func startLiteConversation() {
        habitFlow.reset()
        let opener = BuddyLogic.liteReply(
            to: "hey",
            habits: viewModel.habits,
            buddyName: buddyName,
            pickIndex: 0
        )
        buddyService.startNewConversation(greeting: opener)
    }

    private var habitSnapshots: [BuddyHabitSnapshot] {
        viewModel.habits.map { BuddyHabitSnapshot($0) }
    }

    /// - Parameter quickReply: text from a tapped chip; nil sends the input field.
    private func send(_ quickReply: String? = nil) {
        let text = (quickReply ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Guided add/edit turns don't use up the free daily chat messages.
        let isHabitFlowTurn = BuddyHabitFlow.willHandle(text, state: habitFlow, habits: habitSnapshots, buddyName: buddyName)
        if !isHabitFlowTurn {
            guard BuddyChatUsageLogic.canSendMessage(
                sentToday: buddyService.messagesSentToday,
                isPremium: premiumService.isPremium
            ) else {
                showingPaywall = true
                return
            }
        }

        if shouldStartNewConversation() {
            startLiteConversation()
        }

        let userMessage = ChatMessage(isFromUser: true, text: text)
        buddyService.appendMessage(userMessage)
        buddyService.recordChatActivity(countsTowardLimit: !isHabitFlowTurn)
        if quickReply == nil {
            inputText = ""
            inputFieldID = UUID()
            isInputFocused = true
        }

        if BuddyLogic.containsCrisisSignal(text) {
            habitFlow.reset()
            buddyService.appendMessage(ChatMessage(isFromUser: false, text: BuddyLogic.crisisResponse))
            return
        }

        isThinking = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if let flowReply = BuddyHabitFlow.handle(text, state: &habitFlow, habits: habitSnapshots, buddyName: buddyName) {
                BuddyHabitActionCoordinator.post(flowReply, to: buddyService)
            } else {
                let reply = BuddyLogic.liteReply(
                    to: text,
                    habits: viewModel.habits,
                    buddyName: buddyName
                )
                buddyService.appendMessage(ChatMessage(isFromUser: false, text: reply))
            }
            isThinking = false
        }
    }
}

/// Simple wrapping chip row without a third-party flow layout.
private struct FlexiblePromptWrap: View {
    let prompts: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(stride(from: 0, to: prompts.count, by: 2)), id: \.self) { start in
                HStack(spacing: 8) {
                    promptChip(prompts[start])
                    if start + 1 < prompts.count {
                        promptChip(prompts[start + 1])
                    }
                }
            }
        }
    }

    private func promptChip(_ title: String) -> some View {
        Button {
            onTap(title)
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.primary.opacity(0.12))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
