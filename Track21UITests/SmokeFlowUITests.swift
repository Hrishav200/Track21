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
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()
        return app
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
