//
//  FirstLaunchGuideLogicTests.swift
//  Track21Tests
//

import XCTest
@testable import Track21___21_Day_Habit_Builder

final class FirstLaunchGuideLogicTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "FirstLaunchGuideLogicTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        suite = nil
        super.tearDown()
    }

    func testReturningUserWhoFinishedOnboardingIsMarkedSeen() {
        defaults.set(true, forKey: FirstLaunchGuideLogic.onboardingKey)

        FirstLaunchGuideLogic.migrateReturningUsersIfNeeded(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: FirstLaunchGuideLogic.seenKey))
        XCTAssertNotNil(defaults.object(forKey: FirstLaunchGuideLogic.migratedKey))
    }

    func testFreshInstallStaysEligibleForTheGuide() {
        FirstLaunchGuideLogic.migrateReturningUsersIfNeeded(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: FirstLaunchGuideLogic.seenKey))
        XCTAssertNotNil(defaults.object(forKey: FirstLaunchGuideLogic.migratedKey))
    }

    func testMigrationDoesNotRunAgainAfterOnboardingIsCompletedLater() {
        FirstLaunchGuideLogic.migrateReturningUsersIfNeeded(defaults: defaults)
        defaults.set(true, forKey: FirstLaunchGuideLogic.onboardingKey)

        FirstLaunchGuideLogic.migrateReturningUsersIfNeeded(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: FirstLaunchGuideLogic.seenKey))
    }

    func testGuideWaitsUntilBuddyNamingFinishes() {
        XCTAssertFalse(FirstLaunchGuideLogic.shouldPresent(
            hasSeenGuide: false,
            buddyNamed: false,
            arguments: []
        ))
        XCTAssertTrue(FirstLaunchGuideLogic.shouldPresent(
            hasSeenGuide: false,
            buddyNamed: true,
            arguments: []
        ))
    }

    func testFinishOrSkipKeepsTheGuideHidden() {
        XCTAssertFalse(FirstLaunchGuideLogic.shouldPresent(
            hasSeenGuide: true,
            buddyNamed: true,
            arguments: []
        ))
    }

    func testUITestResetDoesNotBlockOnTheGuide() {
        XCTAssertFalse(FirstLaunchGuideLogic.shouldPresent(
            hasSeenGuide: false,
            buddyNamed: true,
            arguments: ["-uitest-reset"]
        ))
    }

    func testPreviewArgumentShowsTheGuideAnyway() {
        XCTAssertTrue(FirstLaunchGuideLogic.shouldPresent(
            hasSeenGuide: true,
            buddyNamed: true,
            arguments: ["-preview-first-launch-guide"]
        ))
    }
}
