//
//  BuddyNameTests.swift
//  Track21Tests
//
//  Renaming Buddy after onboarding: name validation, persistence through
//  BuddyService, and the "call yourself X" chat flow (which must not steal
//  habit renames like "rename Walk to Evening Walk").
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

@MainActor
struct BuddyNameTests {

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "BuddyNameTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func snap(_ name: String) -> BuddyHabitSnapshot {
        BuddyHabitSnapshot(name: name, goal: "Daily", colorHex: "6BB6FF")
    }

    // MARK: Validation

    @Test func emptyAndWhitespaceNamesAreRejected() {
        #expect(BuddyNameLogic.validate("") == .empty)
        #expect(BuddyNameLogic.validate("   \n  ") == .empty)
        #expect(BuddyNameLogic.validate("\"\"") == .empty)
        #expect(BuddyNameLogic.errorMessage(for: .empty) == "Give your buddy a name.")
    }

    @Test func maxLengthIsEnforced() {
        let exactly24 = String(repeating: "a", count: BuddyNameLogic.maxLength)
        let tooLong = String(repeating: "a", count: BuddyNameLogic.maxLength + 1)
        #expect(BuddyNameLogic.maxLength == 24)
        #expect(BuddyNameLogic.validate(exactly24) == .valid(exactly24))
        #expect(BuddyNameLogic.validate(tooLong) == .tooLong)
        #expect(BuddyNameLogic.errorMessage(for: .tooLong) == "Keep it to 24 characters or fewer.")
        // Surrounding spaces don't count towards the limit.
        #expect(BuddyNameLogic.validate("  \(exactly24)  ") == .valid(exactly24))
    }

    @Test func namesAreTrimmedAndCollapsed() {
        #expect(BuddyNameLogic.validate("  Max  ") == .valid("Max"))
        #expect(BuddyNameLogic.validate("Coach   Rae") == .valid("Coach Rae"))
        #expect(BuddyNameLogic.validate("\u{201C}Max\u{201D}") == .valid("Max"))
        #expect(BuddyNameLogic.validate("'Rae'") == .valid("Rae"))
        #expect(BuddyNameLogic.errorMessage(for: .valid("Max")) == nil)
    }

    @Test func isChangeRequiresAValidDifferentName() {
        #expect(BuddyNameLogic.isChange("Rae", from: "Max"))
        #expect(BuddyNameLogic.isChange("Rae", from: nil))
        #expect(BuddyNameLogic.isChange("max", from: "Max"))
        #expect(!BuddyNameLogic.isChange("Max", from: "Max"))
        #expect(!BuddyNameLogic.isChange("  Max ", from: "Max"))
        #expect(!BuddyNameLogic.isChange("", from: "Max"))
        #expect(!BuddyNameLogic.isChange(String(repeating: "x", count: 25), from: "Max"))
    }

    // MARK: Persistence (same UserDefaults key as first-launch naming)

    @Test func renamePersistsAndReloads() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = BuddyService(defaults: defaults)
        service.saveBuddyName("Max")
        #expect(service.buddyName == "Max")

        #expect(service.renameBuddy(to: "  Coach  Rae ", updatePendingNudge: false) == "Coach Rae")
        #expect(service.buddyName == "Coach Rae")
        #expect(service.hasNamedBuddy)
        #expect(defaults.string(forKey: "Track21BuddyName") == "Coach Rae")

        // A fresh instance (next launch) reads the new name.
        let relaunched = BuddyService(defaults: defaults)
        #expect(relaunched.buddyName == "Coach Rae")
    }

    @Test func invalidRenameLeavesNameUnchanged() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = BuddyService(defaults: defaults)
        service.saveBuddyName("Max")
        #expect(service.renameBuddy(to: "   ", updatePendingNudge: false) == nil)
        #expect(service.renameBuddy(to: String(repeating: "z", count: 25), updatePendingNudge: false) == nil)
        #expect(service.buddyName == "Max")
        #expect(BuddyService(defaults: defaults).buddyName == "Max")
    }

    @Test func firstLaunchNamingStaysLenient() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = BuddyService(defaults: defaults)
        #expect(!service.saveBuddyName("   "))
        #expect(service.buddyName == nil)
        #expect(service.saveBuddyName(String(repeating: "b", count: 30)))
        #expect(service.buddyName == String(repeating: "b", count: 24))
    }

    @Test func renameUpdatesActiveChatAndAnnounces() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = BuddyService(defaults: defaults)
        service.saveBuddyName("Max")
        _ = service.startNewConversation()
        let saved = service.renameBuddy(to: "Rae", updatePendingNudge: false)
        #expect(saved == "Rae")
        service.announceRename("Rae")

        let chat = try! #require(service.activeConversation)
        #expect(chat.buddyName == "Rae")
        #expect(chat.messages.last?.text == "Love it. Call me Rae from now on!")
        // New conversations greet with the new name.
        let fresh = service.startNewConversation()
        #expect(fresh.messages.first?.text.contains("I'm Rae") == true)
    }

    // MARK: Chat flow

    @Test func detectsBuddyRenameIntents() {
        let habits = [snap("Walk")]
        #expect(BuddyHabitFlow.detectIntent("call yourself Max", habits: habits) == .renameBuddy(name: "Max"))
        #expect(BuddyHabitFlow.detectIntent("Can you call yourself coach rae from now on?", habits: habits)
                == .renameBuddy(name: "Coach rae"))
        #expect(BuddyHabitFlow.detectIntent("rename buddy to Rae", habits: habits) == .renameBuddy(name: "Rae"))
        #expect(BuddyHabitFlow.detectIntent("change the buddy's name to Rae", habits: habits) == .renameBuddy(name: "Rae"))
        #expect(BuddyHabitFlow.detectIntent("change your name to Sunny", habits: habits) == .renameBuddy(name: "Sunny"))
        #expect(BuddyHabitFlow.detectIntent("I'll call you Max", habits: habits) == .renameBuddy(name: "Max"))
        #expect(BuddyHabitFlow.detectIntent("rename Max to Rae", habits: habits, buddyName: "Max") == .renameBuddy(name: "Rae"))
        #expect(BuddyHabitFlow.detectIntent("change your name", habits: habits) == .renameBuddy(name: nil))
        #expect(BuddyHabitFlow.detectIntent("can I rename you?", habits: habits) == .renameBuddy(name: nil))
    }

    @Test func nonRenameChatIsLeftAlone() {
        let habits = [snap("Walk")]
        #expect(BuddyHabitFlow.detectIntent("your name is cute", habits: habits) == nil)
        #expect(BuddyHabitFlow.detectIntent("what's your name?", habits: habits) == nil)
        #expect(BuddyHabitFlow.detectIntent("I'll call you later", habits: habits) == nil)
    }

    @Test func habitRenamesStillRenameHabits() {
        let habits = [snap("Walk"), snap("Buddy")]
        #expect(BuddyHabitFlow.detectIntent("rename Walk to Evening Walk", habits: habits, buddyName: "Max")
                == .edit(target: "Walk", field: .name, value: "Evening Walk"))
        // A habit literally called "Buddy" wins over renaming the buddy.
        #expect(BuddyHabitFlow.detectIntent("rename Buddy to Pal", habits: habits, buddyName: "Max")
                == .edit(target: "Buddy", field: .name, value: "Pal"))
        // And a habit sharing Buddy's current name wins too.
        let shared = [snap("Max")]
        #expect(BuddyHabitFlow.detectIntent("rename Max to Rae", habits: shared, buddyName: "Max")
                == .edit(target: "Max", field: .name, value: "Rae"))
    }

    @Test func renameProposalNeedsConfirmation() throws {
        var state = BuddyHabitFlowState()
        let reply = try #require(BuddyHabitFlow.handle("call yourself Rae", state: &state, habits: [], buddyName: "Max"))
        let proposal = try #require(reply.proposal)
        #expect(proposal.type == .renameBuddy)
        #expect(proposal.habitName == "Max")
        #expect(proposal.newHabitName == "Rae")
        #expect(reply.text == "Here\u{2019}s my new name. Tap Save and I\u{2019}ll go by Rae.")
        #expect(!state.isActive)
    }

    @Test func askNameStepValidates() throws {
        var state = BuddyHabitFlowState()
        let ask = try #require(BuddyHabitFlow.handle("change your name", state: &state, habits: [], buddyName: "Max"))
        #expect(ask.text == "Sure! What would you like to call me?")
        #expect(state.step == .buddyName)

        let tooLong = try #require(BuddyHabitFlow.handle(String(repeating: "q", count: 30), state: &state, habits: [], buddyName: "Max"))
        #expect(tooLong.proposal == nil)
        #expect(state.step == .buddyName)

        let named = try #require(BuddyHabitFlow.handle("sunny", state: &state, habits: [], buddyName: "Max"))
        #expect(named.proposal?.newHabitName == "Sunny")
        #expect(!state.isActive)
    }

    @Test func sameNameMakesNoProposal() throws {
        var state = BuddyHabitFlowState()
        let reply = try #require(BuddyHabitFlow.handle("call yourself Max", state: &state, habits: [], buddyName: "Max"))
        #expect(reply.proposal == nil)
    }

    @Test func executorNeverRunsBuddyRenameOnHabits() {
        let action = BuddyHabitFlow.renameBuddyProposal(from: "Max", to: "Rae")
        let store = NoopStore()
        let outcome = BuddyHabitActionExecutor.execute(action, status: .confirmed, store: store, userId: nil)
        #expect(outcome == .unsupported)
        #expect(store.calls == 0)
    }

    @Test func confirmingRenameCardSavesName() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = BuddyService(defaults: defaults)
        service.saveBuddyName("Max")
        _ = service.startNewConversation()
        let action = BuddyHabitFlow.renameBuddyProposal(from: "Max", to: "Rae")
        let message = ChatMessage(isFromUser: false, text: "card", pendingAction: action, actionStatus: .pending)
        service.appendMessage(message)

        BuddyHabitActionCoordinator.confirmBuddyRename(messageID: message.id, action: action, buddyService: service)
        #expect(service.buddyName == "Rae")
        #expect(defaults.string(forKey: "Track21BuddyName") == "Rae")
        #expect(service.activeConversation?.messages.first { $0.id == message.id }?.actionStatus == .executed)
        #expect(service.activeConversation?.messages.last?.text == "Love it. Call me Rae from now on!")

        // A second tap does nothing.
        let count = service.activeConversation?.messages.count
        BuddyHabitActionCoordinator.confirmBuddyRename(messageID: message.id, action: action, buddyService: service)
        #expect(service.activeConversation?.messages.count == count)
    }
}

@MainActor
private final class NoopStore: BuddyHabitStore {
    var habits: [Habit] = []
    private(set) var calls = 0
    func addHabit(_ habit: Habit) { calls += 1 }
    func updateHabit(_ habit: Habit) { calls += 1 }
}
