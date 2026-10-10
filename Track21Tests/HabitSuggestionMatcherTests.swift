//
//  HabitSuggestionMatcherTests.swift
//  Track21Tests
//

import XCTest
@testable import Track21___21_Day_Habit_Builder

final class HabitSuggestionMatcherTests: XCTestCase {
    func testRequiredSuggestionsExistWithDescriptions() {
        let expected = [
            "Cold shower": "Do the hard thing on command.",
            "Deep Focus": "One distraction-free block on your top task.",
            "Evening Phone Cutoff": "No scrolling before bed. Protect your sleep.",
            "Next day preparation": "Plan tomorrow tonight. Zero morning friction.",
        ]
        for (title, description) in expected {
            XCTAssertEqual(HabitSuggestionMatcher.suggestion(matching: title)?.description, description)
        }
    }

    func testTitlesAreUniqueAndDescribed() {
        let titles = HabitSuggestion.all.map { HabitSuggestionMatcher.normalized($0.title) }
        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertFalse(titles.contains("deep work"))
        XCTAssertTrue(HabitSuggestion.all.allSatisfy { !$0.description.isEmpty && !$0.icon.isEmpty })
    }

    func testDescriptionsAreShortOneLiners() {
        for suggestion in HabitSuggestion.all {
            XCTAssertLessThanOrEqual(suggestion.description.count, 45, suggestion.title)
            XCTAssertFalse(suggestion.description.contains("\n"), suggestion.title)
        }
    }

    func testMatchIsCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(HabitSuggestionMatcher.suggestion(matching: "  deep focus \n")?.title, "Deep Focus")
        XCTAssertNil(HabitSuggestionMatcher.suggestion(matching: "Deep Foc"))
        XCTAssertNil(HabitSuggestionMatcher.suggestion(matching: "   "))
    }

    func testFillsEmptyDescription() {
        XCTAssertEqual(
            HabitSuggestionMatcher.autoFilledDescription(forName: "cold SHOWER", currentDescription: "", lastAutoFilled: nil),
            "Do the hard thing on command."
        )
    }

    func testReplacesPreviouslyAutoFilledDescription() {
        let previous = HabitSuggestionMatcher.suggestion(matching: "Walk")!.description
        XCTAssertEqual(
            HabitSuggestionMatcher.autoFilledDescription(forName: "Deep Focus", currentDescription: previous, lastAutoFilled: previous),
            "One distraction-free block on your top task."
        )
    }

    func testNeverOverwritesUserTypedDescription() {
        XCTAssertNil(HabitSuggestionMatcher.autoFilledDescription(forName: "Deep Focus", currentDescription: "My own goal", lastAutoFilled: nil))
        XCTAssertNil(HabitSuggestionMatcher.autoFilledDescription(forName: "Deep Focus", currentDescription: "Edited text", lastAutoFilled: "Original auto text"))
    }

    func testNoMatchLeavesDescriptionAlone() {
        XCTAssertNil(HabitSuggestionMatcher.autoFilledDescription(forName: "Juggle", currentDescription: "", lastAutoFilled: nil))
    }
}
