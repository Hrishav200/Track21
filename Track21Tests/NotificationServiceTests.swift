//
//  NotificationServiceTests.swift
//  Track21Tests
//
//  Created by Track21 Team on 11/7/2026.
//
//  Tests the pure request-building logic in NotificationService rather than
//  going through the real UNUserNotificationCenter — scheduling only
//  actually lands in pendingNotificationRequests() once the user has
//  granted notification permission, which can't be done headlessly here
//  (the system "Allow" dialog needs a real tap; see
//  Track21UITests/SmokeFlowUITests.testAddHabitWithReminderGrantsNotificationPermission
//  for the end-to-end permission + scheduling flow).
//

import Testing
import UserNotifications
@testable import Track21___21_Day_Habit_Builder

struct NotificationServiceTests {

    @Test func requestBuildsADailyRepeatingTriggerAtTheChosenTime() throws {
        let habit = Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF")
        habit.reminderTime = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())

        let request = try #require(NotificationService.makeReminderRequest(for: habit))

        #expect(request.identifier == "habit-reminder-\(habit.id.uuidString)")
        #expect(request.content.title == "Time for Drink Water!")
        #expect(request.content.body == "Goal: 8 glasses — keep your streak going.")

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == true)
        #expect(trigger.dateComponents.hour == 9)
        #expect(trigger.dateComponents.minute == 30)
    }

    @Test func requestBuildsARepeatingIntervalTriggerWhenIntervalIsSet() throws {
        let habit = Habit(name: "Stretch", goal: "5 min", color: "5DD167")
        habit.reminderIntervalMinutes = 240 // every 4 hours

        let request = try #require(NotificationService.makeReminderRequest(for: habit))
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)

        #expect(trigger.repeats == true)
        #expect(trigger.timeInterval == 240 * 60)
    }

    @Test func intervalTriggerIsClampedToTheMinimumOneMinuteAppleAllows() throws {
        let habit = Habit(name: "Posture Check", goal: "sit up straight", color: "FF6B9D")
        habit.reminderIntervalMinutes = 0

        let request = try #require(NotificationService.makeReminderRequest(for: habit))
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)

        #expect(trigger.timeInterval == 60)
    }

    @Test func noReminderTimeBuildsNoRequest() {
        let habit = Habit(name: "Read", goal: "20 pages", color: "A78BFA")
        habit.reminderTime = nil

        #expect(NotificationService.makeReminderRequest(for: habit) == nil)
    }

    @Test func identifierIsStablePerHabit() {
        let habit = Habit(name: "Meditate", goal: "10 min", color: "FFD700")
        #expect(NotificationService.reminderIdentifier(for: habit) == NotificationService.reminderIdentifier(for: habit))
        #expect(NotificationService.reminderIdentifier(for: habit).contains(habit.id.uuidString))
    }

    /// Regression test for a real bug: without registering as the
    /// UNUserNotificationCenterDelegate, iOS silently drops a local
    /// notification that fires while the app is in the foreground — no
    /// banner, no sound. Track21App.init() registers this at launch; since
    /// this test runs in-process with the app (it's a unit test, not a UI
    /// test), that init() has already run by the time this executes.
    @Test func delegateIsRegisteredAtLaunch() {
        #expect(UNUserNotificationCenter.current().delegate === NotificationService.shared)
    }

    @Test func reconcileCancelsDeletedAndArchivedButKeepsActiveReminders() {
        let active = Habit(name: "Walk", goal: "20 min", color: "5DD167")
        active.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())

        let activeNoReminder = Habit(name: "Read", goal: "10 pages", color: "6BB6FF")

        let archivedStart = Calendar.current.date(byAdding: .day, value: -40, to: Date()) ?? Date()
        let archived = Habit(name: "Old Yoga", goal: "15 min", color: "A78BFA", startDate: archivedStart)
        archived.reminderTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
        #expect(archived.isArchived)
        #expect(active.isInActiveCycle)

        let deletedId = UUID()
        let pending = [
            NotificationService.reminderIdentifier(for: active),
            NotificationService.reminderIdentifier(for: activeNoReminder),
            NotificationService.reminderIdentifier(for: archived),
            "habit-reminder-\(deletedId.uuidString)",
            "buddy-nudge"
        ]

        let cancel = NotificationService.reminderIdentifiersToCancel(
            pendingIdentifiers: pending,
            habits: [active, activeNoReminder, archived]
        )

        #expect(cancel.contains(NotificationService.reminderIdentifier(for: activeNoReminder)))
        #expect(cancel.contains(NotificationService.reminderIdentifier(for: archived)))
        #expect(cancel.contains("habit-reminder-\(deletedId.uuidString)"))
        #expect(!cancel.contains(NotificationService.reminderIdentifier(for: active)))
        #expect(!cancel.contains("buddy-nudge"))
    }
}
