//
//  NotificationService.swift
//  Track21
//
//  Created by Track21 Team on 11/7/2026.
//

import Foundation
import UserNotifications

/// Which of a habit's two (mutually exclusive) reminder fields is active —
/// shared between AddHabitView/EditHabitView so both offer the same choice.
enum ReminderMode: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case interval = "Custom Interval"
    var id: String { rawValue }
}

/// Schedules and cancels the daily local-notification reminders tied to a
/// habit's `reminderTime`. One repeating notification per habit, keyed by
/// habit id, so re-scheduling (edit) or cancelling (delete/disable) only
/// ever touches that habit's own reminder.
///
/// Request construction (`reminderIdentifier`/`makeReminderRequest`) is kept
/// pure and separate from the `UNUserNotificationCenter` calls so it can be
/// unit tested without depending on notification authorization state, which
/// can't be granted headlessly in a plain XCTest/Swift Testing process.
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {
        super.init()
    }

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    /// Must be called once, as early as possible (Track21App.init()). Without
    /// a delegate, iOS silently drops a local notification that fires while
    /// the app is in the foreground — no banner, no sound — which is
    /// probably why reminders "don't work" on a real device where the app
    /// is naturally open sometimes when a reminder hits, even though
    /// scheduling and permission are both fine.
    func registerAsDelegate() {
        center.delegate = self
    }

    static let reminderIdentifierPrefix = "habit-reminder-"

    static func reminderIdentifier(for habit: Habit) -> String {
        reminderIdentifierPrefix + habit.id.uuidString
    }

    /// Pending habit-reminder ids that should be removed.
    /// Keeps an id only when it belongs to an active-cycle habit that still
    /// has a reminder configured. Deleted habits (id no longer in `habits`),
    /// archived / finished cycles, and active habits with the reminder
    /// turned off are all cancelled. Non-habit ids (buddy nudges) are left
    /// alone.
    static func reminderIdentifiersToCancel(pendingIdentifiers: [String], habits: [Habit]) -> [String] {
        let keep = Set(
            habits.compactMap { habit -> String? in
                guard habit.isInActiveCycle, makeReminderRequest(for: habit) != nil else { return nil }
                return reminderIdentifier(for: habit)
            }
        )
        return pendingIdentifiers.filter { identifier in
            identifier.hasPrefix(reminderIdentifierPrefix) && !keep.contains(identifier)
        }
    }

    /// Builds the reminder notification request for a habit — a fixed
    /// daily time (`reminderTime`) or a repeating interval throughout the
    /// day (`reminderIntervalMinutes`), whichever is set. `nil` if neither
    /// is set. `reminderIntervalMinutes` takes priority if somehow both
    /// ended up set, since the UI treats them as mutually exclusive modes.
    static func makeReminderRequest(for habit: Habit) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.name)!"
        content.body = "Goal: \(habit.goal) — keep your streak going."
        content.sound = .default

        if let minutes = habit.reminderIntervalMinutes {
            // Apple requires >= 60s for a repeating interval trigger.
            let seconds = max(60, minutes * 60)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: true)
            return UNNotificationRequest(identifier: reminderIdentifier(for: habit), content: content, trigger: trigger)
        }

        guard let reminderTime = habit.reminderTime else { return nil }
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
        // Finished / expired cycles must not keep or gain a reminder,
        // even if reminderTime is still stored on the model.
        guard habit.isInActiveCycle, let request = Self.makeReminderRequest(for: habit) else {
            cancelReminder(for: habit)
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        center.add(request)
    }

    func cancelReminder(for habit: Habit) {
        let identifier = Self.reminderIdentifier(for: habit)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// Compares pending local notifications to the current habit list and
    /// cancels reminders whose habit was deleted or is no longer active.
    /// Safe to call on every launch and foreground.
    func reconcilePendingReminders(habits: [Habit]) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let identifiers = Self.reminderIdentifiersToCancel(
                pendingIdentifiers: requests.map(\.identifier),
                habits: habits
            )
            guard !identifiers.isEmpty else { return }
            self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            self.center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
