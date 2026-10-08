//
//  BuddyService.swift
//  Track21
//
//  Owns the buddy's name and the "occasional nudge" local notification.
//  Nudge content picks a pre-written line via BuddyLogic — no network call,
//  no per-message cost — scheduled at most once per BuddyLogic.minimumNudgeInterval.
//

import Foundation
import UserNotifications

@Observable
final class BuddyService {
    static let shared = BuddyService()

    private(set) var buddyName: String?

    /// Injected for tests; the app uses `.standard` via `shared`.
    private let defaults: UserDefaults

    private let buddyNameKey = "Track21BuddyName"
    private let lastNudgeDateKey = "Track21BuddyLastNudgeDate"
    private let nudgeIdentifier = "buddy-nudge"
    private let chatDaysKey = "Track21BuddyChatDays"
    private let dailyMessageCountKey = "Track21BuddyDailyMessageCount"
    private let dailyMessageDateKey = "Track21BuddyDailyMessageDate"
    private let conversationsKey = "Track21BuddyChatConversations"
    private let activeConversationIDKey = "Track21BuddyActiveConversationID"
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Distinct calendar days the user has sent Buddy a message — tracked
    /// only so the Achievements tab can award "Broke the Ice" / "Regular
    /// Check-in" badges; chat content itself is never persisted.
    private(set) var chatDays: Set<String> = []

    /// Messages sent since midnight — the free tier's daily cap, enforced
    /// by BuddyChatUsageLogic. Resets automatically the first time
    /// recordChatActivity is called on a new calendar day.
    private(set) var messagesSentToday: Int = 0

    /// All persisted chat conversations, sorted by most recent first.
    private(set) var conversations: [ChatConversation] = []

    /// The currently active conversation's ID, if any.
    private(set) var activeConversationID: UUID?

    /// The currently active conversation, derived from conversations array.
    var activeConversation: ChatConversation? {
        guard let id = activeConversationID else { return nil }
        return conversations.first { $0.id == id }
    }

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        buddyName = defaults.string(forKey: buddyNameKey)
        chatDays = Set(defaults.stringArray(forKey: chatDaysKey) ?? [])

        if let storedDate = defaults.object(forKey: dailyMessageDateKey) as? Date,
           Calendar.current.isDateInToday(storedDate) {
            messagesSentToday = defaults.integer(forKey: dailyMessageCountKey)
        }

        loadConversations()
    }

    var hasNamedBuddy: Bool { buddyName != nil }
    var chatDayCount: Int { chatDays.count }

    /// - Parameter countsTowardLimit: false for guided add/edit-habit turns,
    ///   which shouldn't use up the free daily chat messages.
    func recordChatActivity(on date: Date = Date(), countsTowardLimit: Bool = true) {
        let key = Self.dayFormatter.string(from: date)
        if !chatDays.contains(key) {
            chatDays.insert(key)
            defaults.set(Array(chatDays), forKey: chatDaysKey)
        }
        guard countsTowardLimit else { return }

        let storedDate = defaults.object(forKey: dailyMessageDateKey) as? Date
        if let storedDate, Calendar.current.isDate(storedDate, inSameDayAs: date) {
            messagesSentToday += 1
        } else {
            messagesSentToday = 1
            defaults.set(date, forKey: dailyMessageDateKey)
        }
        defaults.set(messagesSentToday, forKey: dailyMessageCountKey)
    }

    /// First-launch naming. Lenient: an over-long name is shortened rather
    /// than rejected so onboarding can always continue.
    @discardableResult
    func saveBuddyName(_ name: String) -> Bool {
        let sanitized = BuddyNameLogic.sanitize(name)
        guard !sanitized.isEmpty else { return false }
        let finalName = String(sanitized.prefix(BuddyNameLogic.maxLength))
            .trimmingCharacters(in: .whitespaces)
        buddyName = finalName
        defaults.set(finalName, forKey: buddyNameKey)
        return true
    }

    /// Renames Buddy after onboarding (Profile, chat header, chat flow).
    /// Strict validation; persists exactly like the first-launch name
    /// (local UserDefaults, the name isn't synced to Supabase). Returns the
    /// saved name, or nil if invalid.
    @discardableResult
    func renameBuddy(to name: String, updatePendingNudge: Bool = true) -> String? {
        guard case .valid(let newName) = BuddyNameLogic.validate(name) else { return nil }
        buddyName = newName
        defaults.set(newName, forKey: buddyNameKey)
        // The open chat (shown in Chat History) follows the new name.
        if let index = conversations.firstIndex(where: { $0.id == activeConversationID }),
           conversations[index].buddyName != newName {
            conversations[index].buddyName = newName
            persistConversations()
        }
        if updatePendingNudge {
            refreshPendingNudgeTitle(newName)
        }
        return newName
    }

    /// Posts a short note in the open conversation so the new name shows in chat right away.
    func announceRename(_ newName: String) {
        guard activeConversation != nil else { return }
        appendMessage(ChatMessage(isFromUser: false, text: "Love it. Call me \(newName) from now on!"))
    }

    /// A nudge already scheduled under the old name gets the new title,
    /// keeping its original fire time.
    private func refreshPendingNudgeTitle(_ newName: String) {
        let center = center
        let identifier = nudgeIdentifier
        Task {
            let pending = await center.pendingNotificationRequests()
            guard let request = pending.first(where: { $0.identifier == identifier }),
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return }
            content.title = newName
            var trigger = request.trigger
            if let interval = request.trigger as? UNTimeIntervalNotificationTrigger,
               let fireDate = interval.nextTriggerDate() {
                trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(60, fireDate.timeIntervalSinceNow),
                    repeats: false
                )
            }
            let updated = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(updated)
        }
    }

    /// Call once per app foreground. Schedules a single nudge notification
    /// for later today if enough time has passed since the last one —
    /// no-ops otherwise so repeated calls don't stack up duplicate nudges.
    func scheduleNudgeIfNeeded(for habits: [Habit], now: Date = Date()) {
        guard let buddyName else { return }
        let lastNudgeDate = defaults.object(forKey: lastNudgeDateKey) as? Date
        guard BuddyLogic.isNudgeDue(lastNudgeDate: lastNudgeDate, now: now) else { return }

        let category = BuddyLogic.category(for: habits, now: now)
        let line = BuddyLogic.randomLine(for: category)
        let fireDate = BuddyLogic.nextNudgeFireDate(now: now)

        let content = UNMutableNotificationContent()
        content.title = buddyName
        content.body = line
        content.sound = .default

        let interval = max(60, fireDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: nudgeIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [nudgeIdentifier])
        center.add(request)
        defaults.set(now, forKey: lastNudgeDateKey)
    }

    // MARK: - Chat History

    /// Loads conversations from UserDefaults on init.
    private func loadConversations() {
        if let data = defaults.data(forKey: conversationsKey),
           let decoded = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            conversations = decoded.sorted { $0.lastMessageAt > $1.lastMessageAt }
        }
        if let idString = defaults.string(forKey: activeConversationIDKey),
           let id = UUID(uuidString: idString) {
            activeConversationID = id
        }
    }

    /// Starts a new conversation with an initial buddy greeting.
    @discardableResult
    func startNewConversation(greeting: String? = nil) -> ChatConversation {
        let greeting = greeting ?? "Hey, I'm \(buddyName ?? "your buddy"). What's on your mind today?"
        let initialMessage = ChatMessage(isFromUser: false, text: greeting)
        let conversation = ChatConversation(
            buddyName: buddyName ?? "Buddy",
            messages: [initialMessage]
        )
        conversations.insert(conversation, at: 0)
        activeConversationID = conversation.id
        persistConversations()
        return conversation
    }

    /// Appends a message to the active conversation and persists.
    func appendMessage(_ message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == activeConversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].lastMessageAt = message.timestamp
        // Re-sort so active conversation floats to top
        conversations.sort { $0.lastMessageAt > $1.lastMessageAt }
        persistConversations()
    }

    /// Updates the action status of a message in the active conversation.
    func updateMessageActionStatus(messageID: UUID, status: ActionStatus) {
        guard let convIndex = conversations.firstIndex(where: { $0.id == activeConversationID }),
              let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        conversations[convIndex].messages[msgIndex].actionStatus = status
        persistConversations()
    }

    /// Resumes an existing conversation by setting it as active.
    func resumeConversation(_ conversation: ChatConversation) {
        activeConversationID = conversation.id
        defaults.set(conversation.id.uuidString, forKey: activeConversationIDKey)
    }

    /// Clears all chat history.
    func clearChatHistory() {
        conversations = []
        activeConversationID = nil
        defaults.removeObject(forKey: conversationsKey)
        defaults.removeObject(forKey: activeConversationIDKey)
    }

    private func persistConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            defaults.set(data, forKey: conversationsKey)
        }
        if let id = activeConversationID {
            defaults.set(id.uuidString, forKey: activeConversationIDKey)
        }
    }

    func clearData() {
        buddyName = nil
        chatDays = []
        messagesSentToday = 0
        defaults.removeObject(forKey: buddyNameKey)
        defaults.removeObject(forKey: lastNudgeDateKey)
        defaults.removeObject(forKey: chatDaysKey)
        defaults.removeObject(forKey: dailyMessageCountKey)
        defaults.removeObject(forKey: dailyMessageDateKey)
        center.removePendingNotificationRequests(withIdentifiers: [nudgeIdentifier])
        clearChatHistory()
    }
}
