//
//  BuddyHabitFlowTests.swift
//  Track21Tests
//
//  Covers Buddy's add/edit-habit chat flow: intent detection, slot filling,
//  edit matching and the confirm-only-then-mutate rule.
//

import Testing
import Foundation
@testable import Track21___21_Day_Habit_Builder

@MainActor
private final class FakeHabitStore: BuddyHabitStore {
    var habits: [Habit]
    private(set) var addCalls = 0
    private(set) var updateCalls = 0

    init(_ habits: [Habit] = []) { self.habits = habits }

    func addHabit(_ habit: Habit) {
        addCalls += 1
        habits.append(habit)
    }

    func updateHabit(_ habit: Habit) {
        updateCalls += 1
        if let index = habits.firstIndex(where: { $0.id == habit.id }) { habits[index] = habit }
    }
}

@MainActor
struct BuddyHabitFlowTests {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: Date()))!
    }

    private func snap(_ name: String, goal: String = "Daily", color: String = "6BB6FF", editable: Bool = true) -> BuddyHabitSnapshot {
        BuddyHabitSnapshot(name: name, goal: goal, colorHex: color, isEditable: editable)
    }

    // MARK: Intent detection

    @Test func detectsAddIntents() {
        #expect(BuddyHabitFlow.detectIntent("add a habit", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.detectIntent("Can you add a new habit?", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.detectIntent("add a habit called meditate", habits: []) == .add(name: "Meditate"))
        #expect(BuddyHabitFlow.detectIntent("I want to start meditating", habits: []) == .add(name: "Meditate"))
        #expect(BuddyHabitFlow.detectIntent("I'd like to start journaling.", habits: []) == .add(name: "Journal"))
        #expect(BuddyHabitFlow.detectIntent("new habit: yoga", habits: []) == .add(name: "Yoga"))
        #expect(BuddyHabitFlow.detectIntent("add cold shower as a habit", habits: []) == .add(name: "Cold shower"))
        #expect(BuddyHabitFlow.detectIntent("start tracking running", habits: []) == .add(name: "Running"))
    }

    @Test func detectsEditIntents() {
        let habits = [snap("Walk"), snap("Read")]
        #expect(BuddyHabitFlow.detectIntent("rename Walk to Evening Walk", habits: habits)
                == .edit(target: "Walk", field: .name, value: "Evening Walk"))
        #expect(BuddyHabitFlow.detectIntent("change the goal of Read to 20 pages", habits: habits)
                == .edit(target: "Read", field: .goal, value: "20 pages"))
        #expect(BuddyHabitFlow.detectIntent("change my Read goal to 20 pages", habits: habits)
                == .edit(target: "Read", field: .goal, value: "20 pages"))
        #expect(BuddyHabitFlow.detectIntent("change the colour of my Walk habit to blue", habits: habits)
                == .edit(target: "Walk", field: .theme, value: "blue"))
        #expect(BuddyHabitFlow.detectIntent("change theme of walk", habits: habits)
                == .edit(target: "walk", field: .theme, value: nil))
        #expect(BuddyHabitFlow.detectIntent("make walk purple", habits: habits)
                == .edit(target: "walk", field: .theme, value: "purple"))
        #expect(BuddyHabitFlow.detectIntent("edit my Walk habit", habits: habits)
                == .edit(target: "Walk", field: nil, value: nil))
        #expect(BuddyHabitFlow.detectIntent("I want to change a habit", habits: habits)
                == .edit(target: nil, field: nil, value: nil))
    }

    @Test func deleteIsNeverSupported() {
        let habits = [snap("Walk")]
        #expect(BuddyHabitFlow.detectIntent("delete my Walk habit", habits: habits) == .deleteUnsupported)
        #expect(BuddyHabitFlow.detectIntent("remove walk", habits: habits) == .deleteUnsupported)
        var state = BuddyHabitFlowState()
        let reply = BuddyHabitFlow.handle("delete my Walk habit", state: &state, habits: habits)
        #expect(reply?.proposal == nil)
        #expect(reply?.text.contains("Home") == true)
        #expect(!state.isActive)
    }

    @Test func ordinaryChatIsNotHabitManagement() {
        let habits = [snap("Walk")]
        for text in ["how am I doing?", "this habit is really hard today", "I want to start over",
                     "change my mindset", "I'm struggling to keep up with my Walk habit", "motivate me",
                     "I want to start today", "thanks!"] {
            #expect(BuddyHabitFlow.detectIntent(text, habits: habits) == nil, "\(text)")
            var state = BuddyHabitFlowState()
            #expect(BuddyHabitFlow.handle(text, state: &state, habits: habits) == nil, "\(text)")
        }
    }

    // MARK: Tolerant detection

    @Test func exactMessageFromDeviceTestStartsAddFlow() {
        #expect(BuddyHabitFlow.detectIntent("Add a habut of eating healthy", habits: []) == .add(name: "Eating healthy"))
        var state = BuddyHabitFlowState()
        let reply = BuddyHabitFlow.handle("Add a habut of eating healthy", state: &state, habits: [])
        #expect(state.step == .addTheme(name: "Eating healthy"))
        #expect(reply?.quickReplies.contains { $0.label == "Coral" } == true)
    }

    @Test func habitTyposAreTolerated() {
        #expect(BuddyHabitFlow.detectIntent("add a habbit called yoga", habits: []) == .add(name: "Yoga"))
        #expect(BuddyHabitFlow.detectIntent("add a hábit", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.detectIntent("create a new hobbit: reading", habits: []) == .add(name: "Read"))
        #expect(BuddyHabitFlow.detectIntent("add habits", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.detectIntent("new habbit", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.canonicalHabitToken("habut") == "habit")
        #expect(BuddyHabitFlow.canonicalHabitToken("Habbits") == "habits")
        #expect(BuddyHabitFlow.canonicalHabitToken("rabbit") == nil)
        #expect(BuddyHabitFlow.canonicalHabitToken("orbit") == nil)
        #expect(BuddyHabitFlow.canonicalHabitToken("habitat") == nil)
        #expect(BuddyHabitFlow.canonicalHabitToken("abit") == nil)
    }

    @Test func phrasingsWithoutTheWordHabit() {
        #expect(BuddyHabitFlow.detectIntent("add eating healthy", habits: []) == .add(name: "Eating healthy"))
        #expect(BuddyHabitFlow.detectIntent("I want to start eating healthy", habits: []) == .add(name: "Eating healthy"))
        #expect(BuddyHabitFlow.detectIntent("help me eat healthier", habits: []) == .add(name: "Eat healthier"))
        #expect(BuddyHabitFlow.detectIntent("help me start journaling", habits: []) == .add(name: "Journal"))
        #expect(BuddyHabitFlow.detectIntent("track my water intake", habits: []) == .add(name: "Water intake"))
        #expect(BuddyHabitFlow.detectIntent("start eating healthy", habits: []) == .add(name: "Eating healthy"))
        #expect(BuddyHabitFlow.detectIntent("begin cold showers", habits: []) == .add(name: "Cold shower"))
        #expect(BuddyHabitFlow.detectIntent("build a habit of reading", habits: []) == .add(name: "Read"))
        #expect(BuddyHabitFlow.detectIntent("create a habit to drink more water", habits: []) == .add(name: "Drink more water"))
        #expect(BuddyHabitFlow.detectIntent("please add a habit named the 5am club", habits: []) == .add(name: "5am club"))
    }

    @Test func tolerantDetectionDoesNotHijackNormalChat() {
        let habits = [snap("Walk")]
        for text in ["help me stay motivated", "start over", "track my progress", "start tracking my progress",
                     "I can't start this habit today", "what habits should I build?", "I watched the hobbit last night",
                     "add some motivation please", "start the day right", "I'm a bit tired", "build muscle",
                     "add 10 minutes to my walk goal", "I want to start feeling better"] {
            #expect(BuddyHabitFlow.detectIntent(text, habits: habits) == nil, "\(text)")
        }
    }

    @Test func looselyWordedRequestsStillStartTheFlow() {
        #expect(BuddyHabitFlow.detectIntent("could we maybe make a new habbit for me", habits: []) == .add(name: nil))
        #expect(BuddyHabitFlow.detectIntent("I'd love to tweak one of my habits", habits: [snap("Walk")])
                == .edit(target: nil, field: nil, value: nil))
    }

    // MARK: Model safety net

    @Test func deflectingModelReplyIsCaught() {
        let bad = "Hey, I can\u{2019}t add habits myself, but you can tap \u{201C}add a habit\u{201D} in the app and let it guide you."
        #expect(BuddyHabitFlow.replyDeflectsHabitManagement(bad))
        #expect(BuddyHabitFlow.replyDeflectsHabitManagement("I'm not able to create a habit for you."))
        #expect(BuddyHabitFlow.replyDeflectsHabitManagement("Tap Add a habit on Home to get started!"))
        #expect(!BuddyHabitFlow.replyDeflectsHabitManagement("You're doing great, keep that walking habit strong!"))
        #expect(!BuddyHabitFlow.replyDeflectsHabitManagement("I can't wait to see you hit day 21!"))
        #expect(!BuddyHabitFlow.replyDeflectsHabitManagement("Love that! Just say 'add a habit' and I'll set it up with you."))
    }

    @Test func safetyNetStartsAddOrEditFlow() {
        var state = BuddyHabitFlowState()
        let add = BuddyHabitFlow.safetyNetReply(forUserText: "Add a habut of eating healthy", state: &state, habits: [])
        #expect(state.step == .addName)
        #expect(add.text == "Want to add a habit? What should it be called?")
        #expect(add.quickReplies.last?.kind == .cancel)
        #expect(add.proposal == nil)

        let walk = snap("Walk")
        var editState = BuddyHabitFlowState()
        _ = BuddyHabitFlow.safetyNetReply(forUserText: "can you change something", state: &editState, habits: [walk])
        #expect(editState.step == .editChooseHabit(candidateIDs: [walk.id], field: nil, value: nil))
    }

    // MARK: Slot filling (add)

    @Test func addFlowAsksNameThenThemeThenGoal() {
        var state = BuddyHabitFlowState()

        let askName = BuddyHabitFlow.handle("add a habit", state: &state, habits: [])
        #expect(state.step == .addName)
        #expect(askName?.quickReplies.contains { $0.value == "Cold shower" } == true)
        #expect(askName?.proposal == nil)

        let askTheme = BuddyHabitFlow.handle("meditate", state: &state, habits: [])
        #expect(state.step == .addTheme(name: "Meditate"))
        let themeLabels = askTheme?.quickReplies.filter { $0.kind == .option }.map(\.label)
        #expect(themeLabels == ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"])

        let askGoal = BuddyHabitFlow.handle("Purple", state: &state, habits: [])
        #expect(state.step == .addGoal(name: "Meditate", colorHex: "A78BFA"))
        let suggestion = HabitSuggestionMatcher.suggestion(matching: "Meditate")!.description
        #expect(askGoal?.quickReplies.first == BuddyQuickReply(label: suggestion, value: suggestion, kind: .suggestion))

        // Tapping the suggestion chip sends its description.
        let confirm = BuddyHabitFlow.handle(suggestion, state: &state, habits: [])
        #expect(!state.isActive)
        let proposal = try! #require(confirm?.proposal)
        #expect(proposal.type == .addHabit)
        #expect(proposal.habitName == "Meditate")
        #expect(proposal.habitColor == "A78BFA")
        #expect(proposal.habitGoal == suggestion)
    }

    @Test func addWithNameSkipsStraightToThemeAndAcceptsTypedGoal() {
        var state = BuddyHabitFlowState()
        _ = BuddyHabitFlow.handle("I want to start running", state: &state, habits: [])
        #expect(state.step == .addTheme(name: "Running"))
        _ = BuddyHabitFlow.handle("make it blue please", state: &state, habits: [])
        #expect(state.step == .addGoal(name: "Running", colorHex: "6BB6FF"))
        let reply = BuddyHabitFlow.handle("5km three times a week", state: &state, habits: [])
        #expect(reply?.proposal?.habitGoal == "5km three times a week")
        #expect(reply?.proposal?.habitName == "Running")
    }

    @Test func invalidThemeReasksAndCancelResets() {
        var state = BuddyHabitFlowState()
        _ = BuddyHabitFlow.handle("add a habit called Yoga", state: &state, habits: [])
        let reask = BuddyHabitFlow.handle("banana", state: &state, habits: [])
        #expect(state.step == .addTheme(name: "Yoga"))
        #expect(reask?.quickReplies.count == 7) // 6 themes + Cancel
        let cancelled = BuddyHabitFlow.handle("Cancel", state: &state, habits: [])
        #expect(!state.isActive)
        #expect(cancelled?.proposal == nil)
    }

    @Test func addRejectsDuplicateActiveName() {
        var state = BuddyHabitFlowState()
        _ = BuddyHabitFlow.handle("add a habit called walk", state: &state, habits: [snap("Walk")])
        #expect(state.step == .addName)
    }

    // MARK: Edit matching

    @Test func editMatchesCaseInsensitivelyAndAsksWhenAmbiguous() {
        let morning = snap("Morning Run")
        let evening = snap("Evening Run")
        let walk = snap("Walk")
        let habits = [morning, evening, walk]

        #expect(BuddyHabitFlow.matches(for: "WALK", in: habits) == [walk])
        #expect(BuddyHabitFlow.matches(for: "run", in: habits) == [morning, evening])

        var state = BuddyHabitFlowState()
        let ask = BuddyHabitFlow.handle("change the goal of my run habit", state: &state, habits: habits)
        #expect(state.step == .editChooseHabit(candidateIDs: [morning.id, evening.id], field: .goal, value: nil))
        #expect(ask?.quickReplies.map(\.label).prefix(2) == ["Morning Run", "Evening Run"])

        _ = BuddyHabitFlow.handle("evening run", state: &state, habits: habits)
        #expect(state.step == .editValue(habitID: evening.id, field: .goal))
        let reply = BuddyHabitFlow.handle("10km on Sundays", state: &state, habits: habits)
        let proposal = try! #require(reply?.proposal)
        #expect(proposal.type == .updateHabit)
        #expect(proposal.targetHabitID == evening.id)
        #expect(proposal.habitGoal == "10km on Sundays")
        #expect(proposal.newHabitName == nil)
        #expect(proposal.habitColor == evening.colorHex)
    }

    @Test func editAsksWhichFieldThenValue() {
        let walk = snap("Walk", color: "6BB6FF")
        var state = BuddyHabitFlowState()
        _ = BuddyHabitFlow.handle("edit my walk habit", state: &state, habits: [walk])
        #expect(state.step == .editChooseField(habitID: walk.id))
        let askTheme = BuddyHabitFlow.handle("Theme", state: &state, habits: [walk])
        #expect(state.step == .editValue(habitID: walk.id, field: .theme))
        #expect(askTheme?.quickReplies.contains { $0.label == "Blue" } == false) // current theme hidden
        let reply = BuddyHabitFlow.handle("Gold", state: &state, habits: [walk])
        #expect(reply?.proposal?.habitColor == "FFD700")
        #expect(reply?.proposal?.habitName == "Walk")
    }

    @Test func renameProposalAndDuplicateGuard() {
        let walk = snap("Walk")
        let read = snap("Read")
        var state = BuddyHabitFlowState()
        let reply = BuddyHabitFlow.handle("rename walk to Evening Walk", state: &state, habits: [walk, read])
        #expect(reply?.proposal?.newHabitName == "Evening Walk")
        #expect(reply?.proposal?.habitName == "Walk")

        var dupState = BuddyHabitFlowState()
        let dup = BuddyHabitFlow.handle("rename walk to read", state: &dupState, habits: [walk, read])
        #expect(dup?.proposal == nil)
        #expect(dupState.step == .editValue(habitID: walk.id, field: .name))
    }

    @Test func archivedHabitsAreReadOnly() {
        let finished = snap("Old Habit", editable: false)
        var state = BuddyHabitFlowState()
        let reply = BuddyHabitFlow.handle("rename Old Habit to New", state: &state, habits: [finished])
        #expect(reply?.proposal == nil)
        #expect(reply?.text.contains("read-only") == true)
        #expect(!state.isActive)
    }

    @Test func unknownHabitOffersActiveHabits() {
        let walk = snap("Walk")
        var state = BuddyHabitFlowState()
        let reply = BuddyHabitFlow.handle("change the goal of my swimming habit", state: &state, habits: [walk])
        #expect(state.step == .editChooseHabit(candidateIDs: [walk.id], field: .goal, value: nil))
        #expect(reply?.quickReplies.first?.label == "Walk")
    }

    // MARK: Confirm-only-then-mutate

    @Test func flowNeverMutatesHabits() {
        let habit = Habit(name: "Walk", goal: "Daily", color: "6BB6FF", startDate: daysAgo(3))
        let store = FakeHabitStore([habit])
        var state = BuddyHabitFlowState()
        for text in ["rename walk to Run", "add a habit", "Yoga", "Pink", "10 minutes"] {
            _ = BuddyHabitFlow.handle(text, state: &state, habits: store.habits.map { BuddyHabitSnapshot($0) })
        }
        #expect(store.addCalls == 0)
        #expect(store.updateCalls == 0)
        #expect(store.habits.count == 1)
        #expect(habit.name == "Walk")
    }

    @Test func executorRefusesUnconfirmedActions() {
        let store = FakeHabitStore()
        let proposal = BuddyHabitFlow.addProposal(name: "Yoga", colorHex: "FF6B9D", goal: "10 minutes")
        for status in [ActionStatus.pending, .cancelled, .executed, .failed] {
            #expect(BuddyHabitActionExecutor.execute(proposal, status: status, store: store, userId: nil) == .notConfirmed)
        }
        #expect(store.habits.isEmpty)
        #expect(store.addCalls == 0)
    }

    @Test func confirmedAddCreatesHabitStartingToday() {
        let store = FakeHabitStore()
        let userId = UUID()
        let proposal = BuddyHabitFlow.addProposal(name: "Yoga", colorHex: "FF6B9D", goal: "10 minutes")
        let outcome = BuddyHabitActionExecutor.execute(proposal, status: .confirmed, store: store, userId: userId)
        let added = try! #require(store.habits.first)
        #expect(outcome == .added(added.id))
        #expect(added.name == "Yoga")
        #expect(added.goal == "10 minutes")
        #expect(added.color == "FF6B9D")
        #expect(added.userId == userId)
        #expect(added.syncStatus == .pending)
        #expect(calendar.isDateInToday(added.startDate))
        #expect(added.reminderTime == nil)
    }

    @Test func confirmedEditKeepsCycleAndStreak() {
        let start = daysAgo(5)
        let completions = [daysAgo(4), daysAgo(3), daysAgo(2)]
        let habit = Habit(name: "Walk", goal: "Daily", color: "6BB6FF", startDate: start, completedDates: completions)
        let store = FakeHabitStore([habit])
        let proposal = BuddyHabitFlow.updateProposal(
            for: BuddyHabitSnapshot(habit),
            name: "Evening Walk",
            goal: "30 minutes",
            colorHex: "5DD167"
        )
        let outcome = BuddyHabitActionExecutor.execute(proposal, status: .confirmed, store: store, userId: nil)
        #expect(outcome == .updated(habit.id))
        #expect(store.updateCalls == 1)
        #expect(habit.name == "Evening Walk")
        #expect(habit.goal == "30 minutes")
        #expect(habit.color == "5DD167")
        #expect(habit.startDate == start)
        #expect(habit.completedDates == completions)
        #expect(habit.syncStatus == .pending)
    }

    @Test func confirmedEditOfArchivedHabitChangesNothing() {
        let habit = Habit(name: "Old", goal: "Daily", color: "6BB6FF", startDate: daysAgo(40))
        #expect(habit.isArchived)
        let store = FakeHabitStore([habit])
        let action = BuddyAction(type: .updateHabit, habitName: "Old", habitGoal: "New goal",
                                 targetHabitID: habit.id, displayText: "", newHabitName: "New")
        #expect(BuddyHabitActionExecutor.execute(action, status: .confirmed, store: store, userId: nil) == .archived)
        #expect(habit.name == "Old")
        #expect(habit.goal == "Daily")
        #expect(store.updateCalls == 0)
    }

    @Test func confirmedDeleteIsRefused() {
        let habit = Habit(name: "Walk", goal: "Daily", color: "6BB6FF")
        let store = FakeHabitStore([habit])
        let action = BuddyAction(type: .deleteHabit, habitName: "Walk", targetHabitID: habit.id, displayText: "")
        #expect(BuddyHabitActionExecutor.execute(action, status: .confirmed, store: store, userId: nil) == .unsupported)
        #expect(store.habits.count == 1)
    }

    @Test func themesMatchAddHabitPresets() {
        #expect(HabitTheme.all.map(\.name) == ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"])
        #expect(HabitTheme.matching("#6bb6ff")?.name == "Blue")
        #expect(HabitTheme.matching("yellow")?.name == "Gold")
        #expect(HabitTheme.matching("banana") == nil)
        #expect(HabitTheme.name(forHex: "123456") == "Custom")
    }
}
