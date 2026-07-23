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

    private let buddyNameKey = "Track21BuddyName"
    private let lastNudgeDateKey = "Track21BuddyLastNudgeDate"
    private let nudgeIdentifier = "buddy-nudge"
    private let chatDaysKey = "Track21BuddyChatDays"
    private let dailyMessageCountKey = "Track21BuddyDailyMessageCount"
    private let dailyMessageDateKey = "Track21BuddyDailyMessageDate"
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

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    private init() {
        buddyName = UserDefaults.standard.string(forKey: buddyNameKey)
        chatDays = Set(UserDefaults.standard.stringArray(forKey: chatDaysKey) ?? [])

        if let storedDate = UserDefaults.standard.object(forKey: dailyMessageDateKey) as? Date,
           Calendar.current.isDateInToday(storedDate) {
            messagesSentToday = UserDefaults.standard.integer(forKey: dailyMessageCountKey)
        }
    }

    var hasNamedBuddy: Bool { buddyName != nil }
    var chatDayCount: Int { chatDays.count }

    func recordChatActivity(on date: Date = Date()) {
        let key = Self.dayFormatter.string(from: date)
        if !chatDays.contains(key) {
            chatDays.insert(key)
            UserDefaults.standard.set(Array(chatDays), forKey: chatDaysKey)
        }

        let storedDate = UserDefaults.standard.object(forKey: dailyMessageDateKey) as? Date
        if let storedDate, Calendar.current.isDate(storedDate, inSameDayAs: date) {
            messagesSentToday += 1
        } else {
            messagesSentToday = 1
            UserDefaults.standard.set(date, forKey: dailyMessageDateKey)
        }
        UserDefaults.standard.set(messagesSentToday, forKey: dailyMessageCountKey)
    }

    func saveBuddyName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        buddyName = trimmed
        UserDefaults.standard.set(trimmed, forKey: buddyNameKey)
    }

    /// Call once per app foreground. Schedules a single nudge notification
    /// for later today if enough time has passed since the last one —
    /// no-ops otherwise so repeated calls don't stack up duplicate nudges.
    func scheduleNudgeIfNeeded(for habits: [Habit], now: Date = Date()) {
        guard let buddyName else { return }
        let lastNudgeDate = UserDefaults.standard.object(forKey: lastNudgeDateKey) as? Date
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
        UserDefaults.standard.set(now, forKey: lastNudgeDateKey)
    }

    func clearData() {
        buddyName = nil
        chatDays = []
        messagesSentToday = 0
        UserDefaults.standard.removeObject(forKey: buddyNameKey)
        UserDefaults.standard.removeObject(forKey: lastNudgeDateKey)
        UserDefaults.standard.removeObject(forKey: chatDaysKey)
        UserDefaults.standard.removeObject(forKey: dailyMessageCountKey)
        UserDefaults.standard.removeObject(forKey: dailyMessageDateKey)
        center.removePendingNotificationRequests(withIdentifiers: [nudgeIdentifier])
    }
}
