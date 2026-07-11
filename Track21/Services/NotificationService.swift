//
//  NotificationService.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import Foundation
import UserNotifications

/// Schedules and cancels the daily local-notification reminders tied to a
/// habit's `reminderTime`. One repeating notification per habit, keyed by
/// habit id, so re-scheduling (edit) or cancelling (delete/disable) only
/// ever touches that habit's own reminder.
///
/// Request construction (`reminderIdentifier`/`makeReminderRequest`) is kept
/// pure and separate from the `UNUserNotificationCenter` calls so it can be
/// unit tested without depending on notification authorization state, which
/// can't be granted headlessly in a plain XCTest/Swift Testing process.
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    static func reminderIdentifier(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)"
    }

    /// Builds the daily-repeating notification request for a habit's
    /// `reminderTime`, or `nil` if no reminder is set.
    static func makeReminderRequest(for habit: Habit) -> UNNotificationRequest? {
        guard let reminderTime = habit.reminderTime else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.name)!"
        content.body = "Goal: \(habit.goal) — keep your streak going."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        return UNNotificationRequest(identifier: reminderIdentifier(for: habit), content: content, trigger: trigger)
    }

    /// Prompts for notification permission. Safe to call on every app
    /// launch — after the first prompt, iOS just returns the existing
    /// status without showing the system dialog again.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedules (or re-schedules) a daily reminder for the habit at its
    /// `reminderTime`. Passing a habit with `reminderTime == nil` cancels
    /// any existing reminder instead.
    func scheduleReminder(for habit: Habit) {
        guard let request = Self.makeReminderRequest(for: habit) else {
            cancelReminder(for: habit)
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        center.add(request)
    }

    func cancelReminder(for habit: Habit) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier(for: habit)])
    }
}
