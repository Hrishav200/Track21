//
//  BuddyChatView.swift
//  Track21
//
//  Free-form chat with the user's on-device accountability buddy. Wrapped in
//  an `if #available` split so the app's deployment target stays iOS 17 —
//  only this tab requires iOS 26 + an Apple Intelligence-eligible device.
//

import SwiftUI
internal import Auth

struct BuddyChatView: View {
    let buddyName: String
    @Bindable var viewModel: HabitViewModel
    let authService: AuthService
    /// False while another tab is showing. Buddy stays mounted so its chat
    /// state survives tab switches, but its input must resign first responder.
    var isTabActive: Bool = true

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26.0, *) {
                    BuddyChatAvailableView(
                        buddyName: buddyName,
                        viewModel: viewModel,
                        authService: authService,
                        isTabActive: isTabActive
                    )
                } else {
                    BuddyLiteChatView(
                        buddyName: buddyName,
                        viewModel: viewModel,
                        availabilityReason: .unsupportedOS,
                        isTabActive: isTabActive,
                        authService: authService
                    )
                }
            }
            .navigationTitle(buddyName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@available(iOS 26.0, *)
private struct BuddyChatAvailableView: View {
    let buddyName: String
    @Bindable var viewModel: HabitViewModel
    let authService: AuthService
    var isTabActive: Bool

    @State private var engine: BuddyChatEngine?
    @State private var availability: BuddyAvailability = .modelNotReady
    @AppStorage("Track21ForceBuddyLite") private var forceBuddyLite = false
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
    /// Guided add/edit-habit conversation (shared with Buddy Lite). Habit
    /// changes never come from the model — only from this flow's
    /// confirmation card.
    @State private var habitFlow = BuddyHabitFlowState()

    /// Messages from the active conversation, or empty if none.
    private var messages: [ChatMessage] {
        buddyService.activeConversation?.messages ?? []
    }

    private var remainingMessages: Int? {
        BuddyChatUsageLogic.remainingMessages(sentToday: buddyService.messagesSentToday, isPremium: premiumService.isPremium)
    }

    /// Whether to auto-start a new conversation (last message >4 hours old).
    private func shouldStartNewConversation() -> Bool {
        guard let active = buddyService.activeConversation else { return true }
        guard let lastMessage = active.messages.last else { return true }
        let fourHours: TimeInterval = 4 * 60 * 60
        return Date().timeIntervalSince(lastMessage.timestamp) > fourHours
    }

    var body: some View {
        Group {
            if availability == .available && !forceBuddyLite {
                chatBody
            } else {
                BuddyLiteChatView(
                    buddyName: buddyName,
                    viewModel: viewModel,
                    // Debug force uses a non-CTA reason so we don't nag to enable AI that is already on.
                    availabilityReason: (forceBuddyLite && availability == .available)
                        ? .deviceNotEligible
                        : availability,
                    isTabActive: isTabActive,
                    authService: authService
                )
            }
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
            availability = BuddyChatEngine.currentAvailability
            if availability == .available && !forceBuddyLite {
                if engine == nil {
                    engine = BuddyChatEngine(buddyName: buddyName)
                }
                // Load existing conversation or start a new one
                if buddyService.activeConversation == nil || shouldStartNewConversation() {
                    buddyService.startNewConversation()
                }
            }
        }
        .toolbar {
            if availability == .available && !forceBuddyLite {
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
                        buddyService.startNewConversation()
                        engine = BuddyChatEngine(buddyName: buddyName)
                        habitFlow.reset()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New conversation")
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(trigger: .chatCapped)
        }
        .sheet(isPresented: $showingHistory) {
            ChatHistoryView(buddyService: buddyService) { conversation in
                buddyService.resumeConversation(conversation)
                engine = BuddyChatEngine(buddyName: buddyName)
                habitFlow.reset()
                showingHistory = false
            }
        }
    }

    private var chatBody: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                BuddyChatBubble(message: message)

                                // Show action card for messages with pending actions
                                if let action = message.pendingAction {
                                    BuddyActionCard(
                                        action: action,
                                        status: message.actionStatus ?? .pending,
                                        onConfirm: { confirmAction(message: message, action: action) },
                                        onCancel: { cancelAction(message: message) }
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
                    .accessibilityLabel("Buddy chat message")
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .id(inputFieldID)

                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : AppTheme.primary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                .accessibilityLabel("Send message")
            }
            .padding()
        }
    }

    private var habitSnapshots: [BuddyHabitSnapshot] {
        viewModel.habits.map { BuddyHabitSnapshot($0) }
    }

    /// - Parameter quickReply: text from a tapped chip; nil sends the input field.
    private func send(_ quickReply: String? = nil) {
        let text = (quickReply ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let engine else { return }

        // Guided add/edit turns don't use up the free daily chat messages.
        let isHabitFlowTurn = BuddyHabitFlow.willHandle(text, state: habitFlow, habits: habitSnapshots)
        if !isHabitFlowTurn {
            guard BuddyChatUsageLogic.canSendMessage(sentToday: buddyService.messagesSentToday, isPremium: premiumService.isPremium) else {
                showingPaywall = true
                return
            }
        }

        // Auto-start new conversation if last message is old
        if shouldStartNewConversation() {
            buddyService.startNewConversation()
            self.engine = BuddyChatEngine(buddyName: buddyName)
            habitFlow.reset()
        }

        let userMessage = ChatMessage(isFromUser: true, text: text)
        buddyService.appendMessage(userMessage)
        buddyService.recordChatActivity(countsTowardLimit: !isHabitFlowTurn)
        if quickReply == nil {
            inputText = ""
            // Multiline TextField(axis: .vertical) can visually keep the old
            // text after clearing the binding while still focused — forcing a
            // fresh identity guarantees it actually clears on screen.
            inputFieldID = UUID()
            isInputFocused = true
        }

        if BuddyLogic.containsCrisisSignal(text) {
            habitFlow.reset()
            let crisisMessage = ChatMessage(isFromUser: false, text: BuddyLogic.crisisResponse)
            buddyService.appendMessage(crisisMessage)
            return
        }

        // Add/edit habit requests are handled deterministically by the
        // shared flow (same as Buddy Lite) — the model is never asked to
        // change habits, so it can't write anything silently.
        if let flowReply = BuddyHabitFlow.handle(text, state: &habitFlow, habits: habitSnapshots) {
            BuddyHabitActionCoordinator.post(flowReply, to: buddyService)
            return
        }

        isThinking = true
        Task {
            do {
                // Update habits context before each request
                engine.updateHabitsContext(viewModel.habits)

                let reply = try await engine.reply(to: text)

                // The model is told not to emit action markers; strip any
                // stray one and ignore it. Habit changes only come from
                // BuddyHabitFlow + the confirmation card.
                let cleaned = BuddyActionParser.parse(reply, habits: viewModel.habits).cleanedText

                // Safety net: if the model still deflects a habit request
                // ("I can't add habits…"), hand over to the guided flow.
                if BuddyHabitFlow.replyDeflectsHabitManagement(cleaned) {
                    let flowReply = BuddyHabitFlow.safetyNetReply(
                        forUserText: text,
                        state: &habitFlow,
                        habits: habitSnapshots
                    )
                    BuddyHabitActionCoordinator.post(flowReply, to: buddyService)
                    isThinking = false
                    return
                }

                let buddyMessage = ChatMessage(
                    isFromUser: false,
                    text: cleaned.isEmpty ? "I\u{2019}m here. Tell me more." : cleaned
                )
                buddyService.appendMessage(buddyMessage)
            } catch {
                NSLog("BuddyChatEngine reply failed: %@", String(describing: error))
                let errorMessage = ChatMessage(isFromUser: false, text: "Sorry, I'm having trouble responding right now — try again in a moment.")
                buddyService.appendMessage(errorMessage)
            }
            isThinking = false
        }
    }

    private func confirmAction(message: ChatMessage, action: BuddyAction) {
        BuddyHabitActionCoordinator.confirm(
            messageID: message.id,
            action: action,
            buddyService: buddyService,
            viewModel: viewModel,
            userId: authService.currentUser?.id
        )
    }

    private func cancelAction(message: ChatMessage) {
        BuddyHabitActionCoordinator.cancel(messageID: message.id, buddyService: buddyService)
    }
}

struct BuddyChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 40) }

            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isFromUser ? AppTheme.primary : AppTheme.cardBackground)
                .foregroundColor(message.isFromUser ? .white : .primary)
                .cornerRadius(18)

            if !message.isFromUser { Spacer(minLength: 40) }
        }
    }
}


/// Dismisses Buddy's input only when the tab is leaving; focus state remains
/// untouched while the user is still typing in Buddy.
enum BuddyKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
