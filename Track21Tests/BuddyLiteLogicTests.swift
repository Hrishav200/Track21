//
//  BuddyLiteLogicTests.swift
//  Track21Tests
//
//  Regression coverage for Buddy Lite intent routing and habit-aware replies.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

struct BuddyLiteLogicTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: reference))!
    }

    private func habit(
        name: String,
        startOffset: Int = 5,
        completedOffsets: [Int] = [],
        includeToday: Bool = false
    ) -> Habit {
        let h = Habit(name: name, goal: "Daily", color: "6BB6FF", startDate: daysAgo(startOffset))
        for offset in completedOffsets {
            h.completedDates.append(daysAgo(offset))
        }
        if includeToday {
            h.completedDates.append(calendar.startOfDay(for: Date()))
        }
        return h
    }

    // MARK: - Intent detection

    @Test func detectsMotivateIntent() {
        #expect(BuddyLogic.detectLiteIntent("can you motivate me") == .motivate)
        #expect(BuddyLogic.detectLiteIntent("I need a pep talk") == .motivate)
    }

    @Test func detectsStatusIntent() {
        #expect(BuddyLogic.detectLiteIntent("how am I doing?") == .status)
        #expect(BuddyLogic.detectLiteIntent("how's my streak") == .status)
    }

    @Test func detectsTodayPlanIntent() {
        #expect(BuddyLogic.detectLiteIntent("what should I do today") == .todayPlan)
        #expect(BuddyLogic.detectLiteIntent("where's my next step") == .todayPlan)
    }

    @Test func detectsStruggleAndGreetingAndThanks() {
        #expect(BuddyLogic.detectLiteIntent("I missed yesterday") == .struggle)
        #expect(BuddyLogic.detectLiteIntent("hey") == .greeting)
        #expect(BuddyLogic.detectLiteIntent("thanks buddy") == .thanks)
    }

    @Test func detectsHabitManagementWithoutHonoringActions() {
        #expect(BuddyLogic.detectLiteIntent("add a habit called Meditate") == .habitManagement)
    }

    @Test func crisisIntentWinsOverEverything() {
        #expect(BuddyLogic.detectLiteIntent("I want to kill myself") == .crisis)
        let reply = BuddyLogic.liteReply(
            to: "I want to kill myself",
            habits: [],
            buddyName: "Sam",
            pickIndex: 0
        )
        #expect(reply == BuddyLogic.crisisResponse)
    }

    // MARK: - Habit-aware replies

    @Test func motivateReplyNamesIncompleteHabit() {
        let protein = habit(name: "Protein", completedOffsets: [1, 2, 3], includeToday: false)
        let reply = BuddyLogic.liteReply(
            to: "motivate me",
            habits: [protein],
            buddyName: "Sam",
            pickIndex: 0
        )
        #expect(reply.contains("Protein"))
    }

    @Test func statusReplyListsOpenHabits() {
        let water = habit(name: "Water", completedOffsets: [1], includeToday: false)
        let creatine = habit(name: "Creatine", completedOffsets: [1], includeToday: true)
        let reply = BuddyLogic.liteReply(
            to: "how am I doing",
            habits: [water, creatine],
            buddyName: "Sam",
            pickIndex: 0
        )
        #expect(reply.contains("Water"))
    }

    @Test func todayPlanPointsAtFirstIncomplete() {
        let walk = habit(name: "Walk", completedOffsets: [1, 2], includeToday: false)
        let reply = BuddyLogic.liteReply(
            to: "what should I do today",
            habits: [walk],
            buddyName: "Sam",
            pickIndex: 0
        )
        #expect(reply.contains("Walk"))
    }

    @Test func habitManagementSteersToHome() {
        let reply = BuddyLogic.liteReply(
            to: "add a habit called Yoga",
            habits: [],
            buddyName: "Sam",
            pickIndex: 0
        )
        let lowered = reply.lowercased()
        #expect(lowered.contains("home") || lowered.contains("lite"))
    }

    @Test func softCTAOnlyWhenIntelligenceOffOrModelWarming() {
        #expect(BuddyLogic.liteSoftCTA(for: .appleIntelligenceNotEnabled) != nil)
        #expect(BuddyLogic.liteSoftCTA(for: .modelNotReady) != nil)
        #expect(BuddyLogic.liteSoftCTA(for: .deviceNotEligible) == nil)
        #expect(BuddyLogic.liteSoftCTA(for: .unsupportedOS) == nil)
        #expect(BuddyLogic.liteSoftCTA(for: .available) == nil)
    }

    @Test func liteContextSeparatesCompletedAndIncomplete() {
        let a = habit(name: "A", includeToday: true)
        let b = habit(name: "B", completedOffsets: [1], includeToday: false)
        let ctx = BuddyLogic.liteContext(for: [a, b])
        #expect(ctx.completedNames == ["A"])
        #expect(ctx.incompleteNames == ["B"])
        #expect(ctx.allDoneToday == false)
    }
}
