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

        // The floating "+" is the only add-habit entry point now; matched by
        // its SF Symbol name "plus" rather than its accessibilityLabel.
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

        let statsTab = app.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        // With 2+ habits, Stats opens on the aggregate "All" overview, not
        // any one habit's detail — the ConsistencyRingView hero + donut
        // chart, not the per-habit weekly chart/journey grid.
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Overall Consistency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Consistency Breakdown"].waitForExistence(timeout: 5))
        attach(app, name: "05-stats-all-overview")

        let readChip = app.buttons["Read"]
        XCTAssertTrue(readChip.waitForExistence(timeout: 5))
        readChip.tap()

        // Tapping a habit's chip drills into that habit's own detail view.
        XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["21-Day Journey"].waitForExistence(timeout: 5))
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
    func testLoginFormScrollsFocusedFieldAboveKeyboard() throws {
        let app = launchApp()

        let signUpToggle = app.buttons["Don't have an account? Sign Up"]
        XCTAssertTrue(signUpToggle.waitForExistence(timeout: 10))
        signUpToggle.tap()

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        Thread.sleep(forTimeInterval: 0.6) // let the scroll-to-focused-field animation settle
        attach(app, name: "16-signup-password-focused")

        XCTAssertTrue(passwordField.isHittable, "Focused password field should be scrolled clear of the keyboard")
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

    /// Journal replaced Achievements as the fourth tab (see ContentView) —
    /// this exercises writing today's entry there, then confirms
    /// Achievements is still reachable, just relocated to Profile.
    @MainActor
    func testJournalEntryAndAchievementsFromProfile() throws {
        let app = launchApp()

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        let journalTab = app.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 10))
        journalTab.tap()

        XCTAssertTrue(app.staticTexts["Journal"].waitForExistence(timeout: 5))
        attach(app, name: "18-journal-empty")

        let goodMoodButton = app.buttons["Good"]
        XCTAssertTrue(goodMoodButton.waitForExistence(timeout: 5))
        goodMoodButton.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        Thread.sleep(forTimeInterval: 0.6) // let the keyboard finish animating in and the scroll-to-Save-Entry settle
        attach(app, name: "18b-journal-keyboard-open")

        // Regression check for the "keyboard hides Save Entry" bug: once
        // the keyboard is up, the button's bottom edge must sit above the
        // keyboard's top edge. (isHittable isn't used here — it's an
        // unreliable signal once a system keyboard window exists, since
        // that window's frame is full-screen even though only its bottom
        // portion is actually visible/interactive; a direct tap still
        // lands correctly regardless of what isHittable reports.)
        let saveButton = app.buttons["Save Entry"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) {
            XCTAssertLessThanOrEqual(
                saveButton.frame.maxY, keyboard.frame.minY,
                "Save Entry should be scrolled above the keyboard, not hidden behind it"
            )
        }

        editor.typeText("Got a run in before work.")
        saveButton.tap()

        // A saved entry with a mood/text today should register a 1-day streak.
        XCTAssertTrue(app.staticTexts["1-day streak"].waitForExistence(timeout: 5))

        // The entry should also appear as a standing record in the list
        // below (labeled "Today, <time>"), not just the transient "Saved"
        // flash — otherwise saving looks like it did nothing once that fades.
        let todayRows = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Today,'"))
        XCTAssertTrue(app.staticTexts["All Entries"].waitForExistence(timeout: 5))
        XCTAssertTrue(todayRows.firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "19-journal-today-saved")

        // Saving again should ADD a second entry, not overwrite the first —
        // the composer clears ~1.5s after the "Saved" confirmation fades.
        Thread.sleep(forTimeInterval: 2.0)
        app.buttons["Great"].tap()
        editor.tap()
        editor.typeText("Second entry of the day.")
        saveButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(todayRows.count, 2, "Saving a second time should add a new entry, not replace the first")
        attach(app, name: "19b-journal-two-entries")

        // The Profile button lives in Home's header, which — like every
        // inactive tab — is accessibilityHidden while Journal is active.
        app.buttons["Home"].tap()

        // Achievements moved to Profile — confirm it's still reachable there.
        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        let achievementsRow = app.buttons["Achievements"]
        XCTAssertTrue(achievementsRow.waitForExistence(timeout: 5))
        achievementsRow.tap()

        XCTAssertTrue(app.navigationBars["Achievements"].waitForExistence(timeout: 5))
        attach(app, name: "20-achievements-from-profile")
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

        let statsTab = app.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        XCTAssertTrue(app.staticTexts["21-Day Journey"].waitForExistence(timeout: 5))
        attach(app, name: "10-journey-grid-with-frozen-day")
    }

    /// Verifies the 21-day-cycle celebration screen (HabitVictoryView) via
    /// the debug menu's preview button, since a real 21-day cycle can't be
    /// produced through the UI in a single test run.
    @MainActor
    func testHabitVictoryScreenPreview() throws {
        let app = launchApp()

        let continueAsGuest = app.buttons["Continue as Guest"]
        XCTAssertTrue(continueAsGuest.waitForExistence(timeout: 10))
        continueAsGuest.tap()

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 10))
        profileButton.tap()

        let debugMenuButton = app.buttons["Debug Menu"]
        XCTAssertTrue(debugMenuButton.waitForExistence(timeout: 5))
        debugMenuButton.tap()

        // The debug Form is a lazily-rendered list — a cell this far down
        // (after Premium/StoreKit/Freeze Wallet/Buddy/App Intro) doesn't
        // exist in the AX tree until scrolled into view, unlike a plain
        // waitForExistence which only helps for content already materialized.
        let previewButton = app.buttons["Preview Victory Screen"]
        for _ in 0..<5 where !previewButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        previewButton.tap()

        XCTAssertTrue(app.staticTexts["21 Days Strong!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share the win"].exists)
        Thread.sleep(forTimeInterval: 1.0) // let confetti/entrance animation settle
        attach(app, name: "17-habit-victory-screen")
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
