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
        let app = XCUIApplication()
        app.launch()
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
        attach(app, name: "04-home-with-habit")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
