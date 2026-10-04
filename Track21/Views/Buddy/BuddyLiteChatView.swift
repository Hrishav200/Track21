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

struct BuddyLiteChatView: View {
    let buddyName: String
    @Bindable var viewModel: HabitViewModel
    let availabilityReason: BuddyAvailability
    var isTabActive: Bool = true

    @State private var inputText = ""
    @State private var isThinking = false
    @State private var inputFieldID = UUID()
    @FocusState private var isInputFocused: Bool
    @State private var buddyService = BuddyService.shared
    @State private var premiumService = PremiumService.shared
    @State private var showingPaywall = false
    @State private var showingHistory = false
    @Environment(\.openURL) private var openURL

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

                        if showQuickPrompts {
                            quickPrompts
                                .padding(.top, 4)
                        }

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
                    .accessibilityLabel("Buddy Lite chat message")
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .id(inputFieldID)

                Button(action: send) {
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
        let opener = BuddyLogic.liteReply(
            to: "hey",
            habits: viewModel.habits,
            buddyName: buddyName,
            pickIndex: 0
        )
        buddyService.startNewConversation(greeting: opener)
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard BuddyChatUsageLogic.canSendMessage(
            sentToday: buddyService.messagesSentToday,
            isPremium: premiumService.isPremium
        ) else {
            showingPaywall = true
            return
        }

        if shouldStartNewConversation() {
            startLiteConversation()
        }

        let userMessage = ChatMessage(isFromUser: true, text: text)
        buddyService.appendMessage(userMessage)
        buddyService.recordChatActivity()
        inputText = ""
        inputFieldID = UUID()
        isInputFocused = true

        if BuddyLogic.containsCrisisSignal(text) {
            buddyService.appendMessage(ChatMessage(isFromUser: false, text: BuddyLogic.crisisResponse))
            return
        }

        isThinking = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let reply = BuddyLogic.liteReply(
                to: text,
                habits: viewModel.habits,
                buddyName: buddyName
            )
            buddyService.appendMessage(ChatMessage(isFromUser: false, text: reply))
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
