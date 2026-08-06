//
//  BuddyChatView.swift
//  Track21
//
//  Free-form chat with the user's on-device accountability buddy. Wrapped in
//  an `if #available` split so the app's deployment target stays iOS 17 —
//  only this tab requires iOS 26 + an Apple Intelligence-eligible device.
//

import SwiftUI

struct BuddyChatView: View {
    let buddyName: String

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26.0, *) {
                    BuddyChatAvailableView(buddyName: buddyName)
                } else {
                    BuddyChatUnavailableView(buddyName: buddyName, reason: .unsupportedOS)
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

    @State private var engine: BuddyChatEngine?
    @State private var availability: BuddyAvailability = .modelNotReady
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var inputFieldID = UUID()
    @FocusState private var isInputFocused: Bool
    @State private var buddyService = BuddyService.shared
    @State private var premiumService = PremiumService.shared
    @State private var showingPaywall = false
    @State private var showingHistory = false

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
            if availability == .available {
                chatBody
            } else {
                BuddyChatUnavailableView(buddyName: buddyName, reason: availability)
            }
        }
        .onAppear {
            availability = BuddyChatEngine.currentAvailability
            if availability == .available {
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
                engine = BuddyChatEngine(buddyName: buddyName)
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
                            BuddyChatBubble(message: message)
                                .id(message.id)
                        }
                        if isThinking {
                            HStack {
                                ProgressView()
                                    .padding(.leading, 4)
                                Spacer()
                            }
                        }

                        // A dedicated, always-empty anchor rather than
                        // scrolling to the newest message bubble directly —
                        // scrolling to a bubble whose multiline text hasn't
                        // finished laying out yet in the LazyVStack can land
                        // short, leaving it clipped under the nav bar.
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture { isInputFocused = false }
                .onChange(of: buddyService.activeConversation?.messages.count) { scrollToBottom(using: proxy) }
                .onChange(of: isThinking) { scrollToBottom(using: proxy) }
                .onChange(of: isInputFocused) { scrollToBottom(using: proxy) }
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

                Button(action: send) {
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

    /// Deferred a tick so the just-added message/keyboard-avoidance layout
    /// has actually settled before scrolling — scrolling within the same
    /// run loop pass as the content change is what left the newest reply
    /// clipped under the nav bar.
    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let engine else { return }

        guard BuddyChatUsageLogic.canSendMessage(sentToday: buddyService.messagesSentToday, isPremium: premiumService.isPremium) else {
            showingPaywall = true
            return
        }

        // Auto-start new conversation if last message is old
        if shouldStartNewConversation() {
            buddyService.startNewConversation()
            self.engine = BuddyChatEngine(buddyName: buddyName)
        }

        let userMessage = ChatMessage(isFromUser: true, text: text)
        buddyService.appendMessage(userMessage)
        buddyService.recordChatActivity()
        inputText = ""
        // Multiline TextField(axis: .vertical) can visually keep the old
        // text after clearing the binding while still focused — forcing a
        // fresh identity guarantees it actually clears on screen.
        inputFieldID = UUID()
        isInputFocused = true

        if BuddyLogic.containsCrisisSignal(text) {
            let crisisMessage = ChatMessage(isFromUser: false, text: BuddyLogic.crisisResponse)
            buddyService.appendMessage(crisisMessage)
            return
        }

        isThinking = true
        Task {
            do {
                let reply = try await engine.reply(to: text)
                let buddyMessage = ChatMessage(isFromUser: false, text: reply)
                buddyService.appendMessage(buddyMessage)
            } catch {
                NSLog("BuddyChatEngine reply failed: %@", String(describing: error))
                let errorMessage = ChatMessage(isFromUser: false, text: "Sorry, I'm having trouble responding right now — try again in a moment.")
                buddyService.appendMessage(errorMessage)
            }
            isThinking = false
        }
    }
}

private struct BuddyChatBubble: View {
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

private struct BuddyChatUnavailableView: View {
    let buddyName: String
    let reason: BuddyAvailability

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("\(buddyName)\(reason.explanation)")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Buddy chat unavailable")
    }
}

#Preview {
    BuddyChatView(buddyName: "Max")
}
