//
//  BuddyChatAutoScroll.swift
//  Track21
//
//  Keeps Buddy's chat (full and Lite) pinned to the newest message.
//
//  Why the old version missed: it only scrolled when the message *count*,
//  the thinking spinner or focus changed, with one scroll on the next run
//  loop. It never scrolled on appear, ignored cards/chips/status changes on
//  an existing message, and inside a LazyVStack the just-inserted bubble or
//  card often isn't measured yet, so a single scrollTo landed short. Focus
//  changes also scrolled before the keyboard finished resizing the view.
//

import SwiftUI
import UIKit

enum BuddyChatScroll {
    static let bottomID = "buddy-chat-bottom"
}

/// Everything that can change what's at the bottom of the chat.
struct BuddyChatScrollSignature: Equatable {
    var messageCount: Int
    var lastMessageID: UUID?
    var lastIsFromUser: Bool
    var lastTextLength: Int
    var actionStatuses: [String]
    var quickReplyCount: Int
    var isThinking: Bool

    init(messages: [ChatMessage], isThinking: Bool) {
        let last = messages.last
        messageCount = messages.count
        lastMessageID = last?.id
        lastIsFromUser = last?.isFromUser ?? false
        lastTextLength = last?.text.count ?? 0
        actionStatuses = messages.compactMap { $0.actionStatus?.rawValue }
        quickReplyCount = last?.quickReplies?.count ?? 0
        self.isThinking = isThinking
    }

    /// The user just sent something (typed or tapped a chip): always follow.
    func isNewUserMessage(comparedTo old: BuddyChatScrollSignature) -> Bool {
        lastIsFromUser && lastMessageID != old.lastMessageID
    }
}

/// Invisible bottom anchor. Its appear/disappear tells us whether the user
/// is reading near the bottom, so new Buddy content doesn't yank someone
/// who scrolled up to read history.
struct BuddyChatBottomAnchor: View {
    @Binding var isNearBottom: Bool

    var body: some View {
        Color.clear
            .frame(height: 1)
            .id(BuddyChatScroll.bottomID)
            .onAppear { isNearBottom = true }
            .onDisappear { isNearBottom = false }
    }
}

struct BuddyChatAutoScroll: ViewModifier {
    let proxy: ScrollViewProxy
    let signature: BuddyChatScrollSignature
    @Binding var isNearBottom: Bool
    let isInputFocused: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                scrollToBottom(animated: false)
            }
            .onChange(of: signature) { old, new in
                // Decide now, before the new content's layout can push the
                // anchor off screen and flip isNearBottom.
                guard new.isNewUserMessage(comparedTo: old) || isNearBottom else { return }
                scrollToBottom(animated: true)
            }
            .onChange(of: isInputFocused) { _, focused in
                guard focused else { return }
                scrollToBottom(animated: true, delay: 0.3)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                scrollToBottom(animated: true)
            }
    }

    /// Scrolls on the next run loop, then once more after lazy rows have
    /// been measured so tall bubbles/cards don't end up clipped.
    private func scrollToBottom(animated: Bool, delay: TimeInterval = 0) {
        let proxy = proxy
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(BuddyChatScroll.bottomID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(BuddyChatScroll.bottomID, anchor: .bottom)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(BuddyChatScroll.bottomID, anchor: .bottom)
                }
            }
        }
    }
}

extension View {
    func buddyChatAutoScroll(
        proxy: ScrollViewProxy,
        signature: BuddyChatScrollSignature,
        isNearBottom: Binding<Bool>,
        isInputFocused: Bool
    ) -> some View {
        modifier(BuddyChatAutoScroll(
            proxy: proxy,
            signature: signature,
            isNearBottom: isNearBottom,
            isInputFocused: isInputFocused
        ))
    }
}
