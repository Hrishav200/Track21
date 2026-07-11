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
}
