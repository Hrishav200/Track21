//
//  SmokeFlowUITests.swift
//  Track21UITests
//
//  Driver for the run-track21 skill: exercises the guest login -> add habit
//  flow end-to-end and attaches a screenshot after each step so an agent
//  can inspect what the app actually rendered.
//

import XCTest

final class SmokeFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestAddHabitFlow() throws {
        let app = launchApp()
        attach(app, name: "01-login")

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        // Both the tab bar "+" and the in-list "Add New Habit" button share the
        // accessibilityLabel "Add new habit" (one label, two buttons) — the tab
        // bar one is uniquely identified by its SF Symbol name "plus".
        let addHabitButton = app.buttons["plus"]
        XCTAssertTrue(addHabitButton.waitForExistence(timeout: 10))
        attach(app, name: "02-home-empty")
        addHabitButton.tap()

        let nameField = app.textFields["Habit name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Drink Water")

        let goalField = app.textFields["Goal (e.g., 30min, 5km)"]
        goalField.tap()
        goalField.typeText("8 glasses")

        attach(app, name: "03-add-habit-form")
        app.navigationBars["New Habit"].buttons["Add"].tap()

        let habitCard = app.staticTexts["Drink Water"]
        XCTAssertTrue(habitCard.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6) // let the sheet-dismiss animation settle before screenshotting
        attach(app, name: "04-home-with-habit")
    }

    @MainActor
    func testAddHabitWithReminderGrantsNotificationPermission() throws {
        // The notification permission alert belongs to springboard, not this
        // app — an interruption monitor is how XCUITest taps "Allow" on it.
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            guard alert.buttons["Allow"].exists else { return false }
            alert.buttons["Allow"].tap()
            return true
        }

        let app = launchApp()

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        // ContentView's .task fires requestAuthorizationIfNeeded() on appear;
        // a harmless tap forces XCUITest to service the interruption monitor.
        app.tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.tap()

        addHabit(app, name: "Drink Water", goal: "8 glasses", enableReminder: true)
        attach(app, name: "08-home-with-reminder-habit")
    }

    @MainActor
    func testStatsTabShowsHabitProgress() throws {
        let app = launchApp()

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        addHabit(app, name: "Drink Water", goal: "8 glasses")
        app.buttons["Mark Drink Water complete"].tap()

        addHabit(app, name: "Read", goal: "20 pages")

        let statsTab = app.buttons["Statistics"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["21-Day Journey"].waitForExistence(timeout: 5))
        attach(app, name: "05-stats-first-habit")

        let readChip = app.buttons["Read"]
        XCTAssertTrue(readChip.waitForExistence(timeout: 5))
        readChip.tap()
        attach(app, name: "06-stats-second-habit")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["All Habits"].waitForExistence(timeout: 5))
        attach(app, name: "07-stats-all-habits")
    }

    /// Launches with a flag that makes the app clear its persisted habits on
    /// launch, so each test starts from a clean slate instead of piling up
    /// "Drink Water" habits left over from previous runs in this session.
    @MainActor
    func testBuddyOnboardingAndChatTab() throws {
        let app = launchApp(extraArguments: ["-uitest-fresh-buddy"])

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        let buddyNameField = app.textFields["Buddy name"]
        XCTAssertTrue(buddyNameField.waitForExistence(timeout: 10))
        buddyNameField.tap()
        buddyNameField.typeText("Sam")
        attach(app, name: "12-buddy-naming")

        // iOS 26's first-run "continuous path" keyboard tutorial also has a
        // "Continue" button in a separate window, so the label alone is
        // ambiguous — the accessibility identifier disambiguates it.
        app.buttons["buddyNamingContinue"].tap()

        let buddyTab = app.buttons["Buddy"]
        XCTAssertTrue(buddyTab.waitForExistence(timeout: 10))
        buddyTab.tap()

        XCTAssertTrue(app.navigationBars["Sam"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.6) // let the availability check settle before screenshotting
        attach(app, name: "13-buddy-chat")

        // On-device chat only exists where Foundation Models is actually
        // available (iOS 26 + Apple Intelligence) — elsewhere this device
        // sees the fallback message instead, which is already covered above.
        let messageField = app.textFields["Buddy chat message"]
        if messageField.waitForExistence(timeout: 3) {
            messageField.tap()
            messageField.typeText("I keep skipping my running habit")
            app.buttons["Send message"].tap()

            // Scoped to the chat scroll view specifically — the keyboard's
            // QuickType suggestion bar also contains staticTexts, which
            // otherwise satisfy a same-screen "any new text" predicate long
            // before the model actually replies.
            let newReply = app.scrollViews.staticTexts.matching(NSPredicate(
                format: "label != %@ AND label != %@",
                "Hey, I'm Sam. What's on your mind today?",
                "I keep skipping my running habit"
            ))
            XCTAssertTrue(newReply.firstMatch.waitForExistence(timeout: 30))
            attach(app, name: "14-buddy-chat-reply")

            // Re-focus the field after a reply landed — this is where the
            // keyboard's "Done" accessory button was seen floating over the
            // input row instead of sitting in its own toolbar strip.
            messageField.tap()
            messageField.typeText("Thanks")
            attach(app, name: "15-buddy-chat-keyboard-toolbar")
        }
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    func testProfileShowsFreezeWalletCard() throws {
        let app = launchApp()

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 10))
        profileButton.tap()

        XCTAssertTrue(app.staticTexts["Streak Freezes"].waitForExistence(timeout: 5))
        attach(app, name: "11-profile-freeze-wallet")
    }

    /// Seeds a habit with a completed/frozen/missed mix (via
    /// -uitest-seed-frozen-habit) so the streak-freeze UI — the journey
    /// grid's ice-blue cell, the weekly calendar's snowflake, and the
    /// header's freeze-count badge — can be screenshotted without waiting
    /// for a real missed day to trigger auto-protection.
    @MainActor
    func testFrozenDayRendersInJourneyGridAndHeader() throws {
        let app = launchApp(extraArguments: ["-uitest-seed-frozen-habit"])

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        XCTAssertTrue(app.staticTexts["Drink Water"].waitForExistence(timeout: 10))
        attach(app, name: "09-home-with-frozen-day")

        let statsTab = app.buttons["Statistics"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        XCTAssertTrue(app.staticTexts["21-Day Journey"].waitForExistence(timeout: 5))
        attach(app, name: "10-journey-grid-with-frozen-day")
    }

    @MainActor
    private func addHabit(_ app: XCUIApplication, name: String, goal: String, enableReminder: Bool = false) {
        app.buttons["plus"].tap()

        let nameField = app.textFields["Habit name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        let goalField = app.textFields["Goal (e.g., 30min, 5km)"]
        goalField.tap()
        goalField.typeText(goal)

        if enableReminder {
            let reminderToggle = app.switches.firstMatch
            XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5))
            reminderToggle.tap()
        }

        app.navigationBars["New Habit"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
