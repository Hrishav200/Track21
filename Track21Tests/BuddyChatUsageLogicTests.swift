//
//  BuddyChatUsageLogicTests.swift
//  Track21Tests
//

import Testing
@testable import Track21___21_Day_Habit_Builder

struct BuddyChatUsageLogicTests {
    @Test func freeUserCanSendUntilTheDailyLimit() {
        #expect(BuddyChatUsageLogic.canSendMessage(sentToday: 0, isPremium: false))
        #expect(BuddyChatUsageLogic.canSendMessage(sentToday: 4, isPremium: false))
        #expect(!BuddyChatUsageLogic.canSendMessage(sentToday: 5, isPremium: false))
        #expect(!BuddyChatUsageLogic.canSendMessage(sentToday: 10, isPremium: false))
    }

    @Test func premiumUserIsNeverCapped() {
        #expect(BuddyChatUsageLogic.canSendMessage(sentToday: 5, isPremium: true))
        #expect(BuddyChatUsageLogic.canSendMessage(sentToday: 1000, isPremium: true))
    }

    @Test func remainingMessagesCountsDownForFreeUsers() {
        #expect(BuddyChatUsageLogic.remainingMessages(sentToday: 0, isPremium: false) == 5)
        #expect(BuddyChatUsageLogic.remainingMessages(sentToday: 3, isPremium: false) == 2)
        #expect(BuddyChatUsageLogic.remainingMessages(sentToday: 5, isPremium: false) == 0)
        #expect(BuddyChatUsageLogic.remainingMessages(sentToday: 9, isPremium: false) == 0)
    }

    @Test func remainingMessagesIsNilForPremium() {
        #expect(BuddyChatUsageLogic.remainingMessages(sentToday: 0, isPremium: true) == nil)
    }
}
