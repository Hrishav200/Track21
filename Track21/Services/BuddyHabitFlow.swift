//
//  BuddyHabitFlow.swift
//  Track21
//
//  Shared, deterministic add/edit-habit conversation used by BOTH Buddy
//  paths: full Buddy (Apple Foundation Models) and Buddy Lite (templates).
//
//  - `detectIntent` spots "add a habit", "I want to start meditating",
//    "rename X to Y", "change the goal of X", "change X's theme to blue"…
//  - `handle` walks the missing slots (name -> theme -> goal for adds;
//    habit -> field -> value for edits) and returns Buddy's reply plus
//    tappable quick replies.
//  - When every slot is filled it returns a `BuddyAction` *proposal* for the
//    confirmation card. Nothing here ever touches habits: the only mutation
//    path is `BuddyHabitActionExecutor.execute`, which refuses to run unless
//    the card was confirmed.
//  - Deleting via chat is deliberately unsupported.
//

import Foundation

// MARK: - Inputs

/// Value snapshot of a habit so the flow stays pure and unit-testable.
struct BuddyHabitSnapshot: Equatable {
    let id: UUID
    let name: String
    let goal: String
    let colorHex: String
    /// Only habits in an open 21-day cycle can be edited (archived = read-only).
    let isEditable: Bool

    init(id: UUID = UUID(), name: String, goal: String, colorHex: String, isEditable: Bool = true) {
        self.id = id
        self.name = name
        self.goal = goal
        self.colorHex = colorHex
        self.isEditable = isEditable
    }

    init(_ habit: Habit) {
        self.init(
            id: habit.id,
            name: habit.name,
            goal: habit.goal,
            colorHex: habit.color,
            isEditable: habit.isInActiveCycle
        )
    }
}

enum BuddyHabitField: String, Equatable, CaseIterable {
    case name
    case theme
    case goal

    var label: String {
        switch self {
        case .name: return "Name"
        case .theme: return "Theme"
        case .goal: return "Goal"
        }
    }
}

enum BuddyHabitIntent: Equatable {
    case add(name: String?)
    case edit(target: String?, field: BuddyHabitField?, value: String?)
    case deleteUnsupported
}

enum BuddyHabitFlowStep: Equatable {
    case idle
    case addName
    case addTheme(name: String)
    case addGoal(name: String, colorHex: String)
    case editChooseHabit(candidateIDs: [UUID], field: BuddyHabitField?, value: String?)
    case editChooseField(habitID: UUID)
    case editValue(habitID: UUID, field: BuddyHabitField)
}

struct BuddyHabitFlowState: Equatable {
    var step: BuddyHabitFlowStep = .idle

    var isActive: Bool { step != .idle }

    mutating func reset() {
        step = .idle
    }
}

struct BuddyHabitFlowReply: Equatable {
    var text: String
    var quickReplies: [BuddyQuickReply] = []
    /// Set when all slots are filled: shown as a confirmation card. Never executed here.
    var proposal: BuddyAction? = nil
}

// MARK: - Flow

enum BuddyHabitFlow {

    // MARK: Public entry points

    /// Returns nil when the message isn't habit management (normal chat should answer).
    static func handle(
        _ rawText: String,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply? {
        let text = BuddyHabitText.clean(rawText)
        guard !text.isEmpty else { return nil }

        if state.isActive {
            if isCancel(text) {
                state.reset()
                return BuddyHabitFlowReply(text: "No worries, I didn\u{2019}t change anything.")
            }
            // On steps that expect a choice (theme, which habit, which field)
            // a fresh request restarts the flow. Free-text steps (name, goal)
            // take the text literally so "change my mindset" can be a goal.
            if !takesFreeText(state.step), let intent = detectIntent(text, habits: habits) {
                return start(intent, state: &state, habits: habits)
            }
            // Raw (trimmed) text so a typed or suggested goal keeps its punctuation.
            let raw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            return continueFlow(raw, state: &state, habits: habits)
        }

        guard let intent = detectIntent(text, habits: habits) else { return nil }
        return start(intent, state: &state, habits: habits)
    }

    /// True when this message would be handled by the flow (used to keep
    /// habit-management turns out of the free daily chat cap).
    static func willHandle(_ text: String, state: BuddyHabitFlowState, habits: [BuddyHabitSnapshot]) -> Bool {
        let cleaned = BuddyHabitText.clean(text)
        guard !cleaned.isEmpty else { return false }
        return state.isActive || detectIntent(cleaned, habits: habits) != nil
    }

    // MARK: Intent detection

    static func detectIntent(_ text: String, habits: [BuddyHabitSnapshot]) -> BuddyHabitIntent? {
        // Typos like "habut", "habbit", "hábit" become "habit" first.
        let core = stripPoliteness(BuddyHabitText.clean(normalizeHabitWords(text)))
        guard !core.isEmpty else { return nil }
        let lower = core.lowercased()
        let mentionsHabit = lower.contains("habit")

        func targetIsKnown(_ target: String?) -> Bool {
            guard let target else { return false }
            return !matches(for: target, in: habits).isEmpty
        }

        // Delete is never done from chat — answer it explicitly.
        if let c = captures(#"^(?:delete|remove|erase|get\s+rid\s+of|stop\s+tracking)\s+(.+)$"#, in: core) {
            let target = cleanTarget(c[0])
            if mentionsHabit || targetIsKnown(target) { return .deleteUnsupported }
        }
        let deleteVerbs = ["delete", "remove", "get rid of", "stop tracking", "erase"]
        if mentionsHabit,
           BuddyLogic.requestsHabitManagement(core),
           deleteVerbs.contains(where: { lower.contains($0) }) {
            return .deleteUnsupported
        }

        // Rename
        if let c = captures(#"^rename\s+(.+?)\s+(?:to|as)\s+(.+)$"#, in: core) {
            return .edit(target: cleanTarget(c[0]), field: .name, value: c[1].map { cleanNameValue($0) })
        }
        if let c = captures(#"^change\s+(?:the\s+)?name\s+(?:of|for)\s+(.+?)(?:\s+to\s+(.+))?$"#, in: core) {
            return .edit(target: cleanTarget(c[0]), field: .name, value: c[1].map { cleanNameValue($0) })
        }
        if let c = captures(#"^rename\s+(.+)$"#, in: core) {
            return .edit(target: cleanTarget(c[0]), field: .name, value: nil)
        }

        let editVerb = #"(?:change|update|set|edit|modify|adjust)"#

        // Goal
        let goalPatterns = [
            #"^"# + editVerb + #"\s+(?:the\s+)?(?:goal|description)\s+(?:of|for|on)\s+(.+?)(?:\s+to\s+(.+))?$"#,
            #"^"# + editVerb + #"\s+(.+?)(?:'s|’s|s')?\s+(?:goal|description)(?:\s+to\s+(.+))?$"#,
        ]
        for pattern in goalPatterns {
            if let c = captures(pattern, in: core) {
                let target = cleanTarget(c[0])
                guard mentionsHabit || targetIsKnown(target) else { break }
                return .edit(target: target, field: .goal, value: c[1])
            }
        }

        // Theme (= background colour)
        let themeWord = #"(?:theme|colou?r|background(?:\s+colou?r)?)"#
        let themePatterns = [
            #"^"# + editVerb + #"\s+(?:the\s+)?"# + themeWord + #"\s+(?:of|for|on)\s+(.+?)(?:\s+to\s+(.+))?$"#,
            #"^"# + editVerb + #"\s+(.+?)(?:'s|’s|s')?\s+"# + themeWord + #"(?:\s+to\s+(.+))?$"#,
            #"^(?:make|turn|paint|change|switch)\s+(.+?)\s+(?:to\s+)?(coral|blue|green|gold|pink|purple)$"#,
        ]
        for pattern in themePatterns {
            if let c = captures(pattern, in: core) {
                let target = cleanTarget(c[0])
                guard mentionsHabit || targetIsKnown(target) else { break }
                return .edit(target: target, field: .theme, value: c[1])
            }
        }

        // Add
        if let c = captures(#"^(?:add|create|start|make|set\s*up|begin|build)\s+(?:a\s+|an\s+|another\s+|one\s+more\s+)?(?:new\s+)?habits?(?:\s+(?:called|named|for|to|of)\s+(.+)|\s*[:\-]\s*(.+)|\s+(.+))?$"#, in: core) {
            return .add(name: extractName(c[0] ?? c[1] ?? c[2]))
        }
        if let c = captures(#"^new\s+habit(?:\s+(?:called|named)\s+(.+)|\s*[:\-]\s*(.+)|\s+(.+))?$"#, in: core) {
            return .add(name: extractName(c[0] ?? c[1] ?? c[2]))
        }
        if let c = captures(#"^(?:add|create)\s+(.+?)\s+(?:as\s+(?:a\s+|my\s+)?(?:new\s+)?habit|to\s+my\s+habits|to\s+my\s+list|habit)$"#, in: core) {
            return .add(name: extractName(c[0]))
        }
        if let c = captures(#"^(?:start\s+tracking|track)\s+(.+)$"#, in: core),
           let name = extractName(c[0]),
           !startsWithAny(c[0] ?? "", trackStopPhrases) {
            return .add(name: name)
        }
        if let c = captures(#"^(?:i\s+want\s+to|i\s+wanna|i'd\s+like\s+to|i’d\s+like\s+to|i\s+would\s+like\s+to|i'm\s+going\s+to|i’m\s+going\s+to|im\s+going\s+to|i'm\s+gonna|i’m\s+gonna|let's|let’s|lets)\s+(?:try\s+to\s+)?(?:start|begin|build|pick\s+up)\s+(.+)$"#, in: core),
           let phrase = c[0] {
            let stripped = stripHabitLead(phrase)
            if startsWithAny(stripped, startStopPhrases) { return nil }
            if let name = extractName(stripped) { return .add(name: name) }
            return phrase.lowercased().contains("habit") ? .add(name: nil) : nil
        }
        // "help me eat healthier", "help me start journaling"
        if let c = captures(#"^help\s+me\s+(?:to\s+)?(.+)$"#, in: core), let phrase = c[0] {
            if let inner = captures(#"^(?:start|begin|build)\s+(.+)$"#, in: phrase)?.first ?? nil {
                let stripped = stripHabitLead(inner)
                if !startsWithAny(stripped, startStopPhrases), let name = extractName(stripped) {
                    return .add(name: name)
                }
            } else if let first = firstWord(of: phrase), habitVerbs.contains(first), let name = extractName(phrase) {
                return .add(name: name)
            }
        }
        // "add eating healthy", "create a morning walk"
        if let c = captures(#"^(?:add|create)\s+(.+)$"#, in: core), let phrase = c[0] {
            let key = phrase.lowercased()
            let looksLikeEdit = key.contains(" to my ") || key.contains("goal") || key.contains("theme")
                || key.contains("colour") || key.contains("color") || key.range(of: #"^\d"#, options: .regularExpression) != nil
            if !looksLikeEdit, !startsWithAny(phrase, addStopPhrases), phrase.split(separator: " ").count <= 6 {
                return .add(name: extractName(phrase))
            }
        }
        // "start eating healthy", "begin journaling", "start cold showers"
        if let c = captures(#"^(?:start|begin|build)\s+(.+)$"#, in: core), let phrase = c[0] {
            let stripped = stripHabitLead(phrase)
            if !startsWithAny(stripped, startStopPhrases), let first = firstWord(of: stripped) {
                let isGerund = first.count >= 5 && first.hasSuffix("ing")
                let name = extractName(stripped)
                let isSuggestion = name.map { HabitSuggestionMatcher.suggestion(matching: $0) != nil } ?? false
                if (isGerund || habitVerbs.contains(first) || isSuggestion), let name {
                    return .add(name: name)
                }
            }
        }

        // Generic edit: "edit my Walk habit", "change Read"
        if let c = captures(#"^(?:edit|change|update|modify|adjust|tweak)\s+(.+)$"#, in: core) {
            let target = cleanTarget(c[0])
            if targetIsKnown(target) { return .edit(target: target, field: nil, value: nil) }
            if mentionsHabit { return .edit(target: target, field: nil, value: nil) }
        }

        // Fallback: a management verb shortly before "habit", no negation.
        return looseIntent(core)
    }

    // MARK: Tolerant matching helpers

    /// Verbs that read as a habit when they follow "help me" / "start".
    static let habitVerbs: Set<String> = [
        "eat", "drink", "sleep", "read", "meditate", "exercise", "walk", "run", "jog", "stretch",
        "journal", "learn", "practice", "practise", "study", "floss", "cook", "wake", "save", "cut",
        "reduce", "limit", "quit", "train", "lift", "swim", "cycle", "write", "pray", "hydrate", "stop",
    ]

    private static let startStopPhrases = [
        "over", "again", "today", "tomorrow", "now", "fresh", "the ", "my day", "a streak", "a new day",
        "working", "my habits", "feeling", "thinking", "getting", "being", "doing", "going", "trying",
        "looking", "a conversation", "a chat", "chatting", "talking", "it", "this", "that", "with",
        "tracking", "my progress", "progress",
    ]

    private static let addStopPhrases = [
        "it", "that", "this", "me", "up", "more", "some", "the ", "a note", "note", "an entry", "entry",
        "a journal entry", "journal entry", "a reminder", "reminder", "a friend", "friend", "buddy",
        "motivation", "encouragement", "a pep talk", "pep talk", "energy", "a photo", "photo", "a comment",
    ]

    private static let trackStopPhrases = [
        "my progress", "progress", "my streak", "streak", "streaks", "my habits", "habits", "how", "what",
        "it", "that", "this", "me", "down", "back",
    ]

    /// True if `text` starts with any phrase (whole-word for single words).
    static func startsWithAny(_ text: String, _ phrases: [String]) -> Bool {
        let key = BuddyHabitText.key(text)
        return phrases.contains { phrase in
            if phrase.hasSuffix(" ") { return key.hasPrefix(phrase) }
            return key == phrase || key.hasPrefix(phrase + " ")
        }
    }

    private static func firstWord(of text: String) -> String? {
        BuddyHabitText.key(text)
            .components(separatedBy: CharacterSet.letters.inverted)
            .first { !$0.isEmpty }
    }

    /// "a new habit of eating healthy" -> "eating healthy"
    private static func stripHabitLead(_ phrase: String) -> String {
        phrase.replacingOccurrences(
            of: #"^(?:a\s+|an\s+|the\s+)?(?:new\s+)?habits?(?:\s+(?:of|called|named|to|for))?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    /// Habit name from a phrase: drops "of", "to", "called", "named",
    /// articles and a trailing "habit"; suggestion title if it matches;
    /// otherwise first letter capitalised ("eating healthy" -> "Eating healthy").
    static func extractName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var text = BuddyHabitText.clean(raw)
        let lead = #"^(?:of|to|called|named|for|about|a|an|the|my)\s+"#
        while let range = text.range(of: lead, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        guard let target = cleanTarget(text) else { return nil }
        let name = canonicalName(target)
        return name.isEmpty ? nil : name
    }

    /// Loose safety net for phrasings the patterns miss: an add/edit verb
    /// within a few words before "habit", and no negation/struggle words
    /// ("I can't start this habit today" stays normal chat).
    static func looseIntent(_ text: String) -> BuddyHabitIntent? {
        let words = normalizeHabitWords(text).lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .components(separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz'").inverted)
            .filter { !$0.isEmpty }
        guard let habitIndex = words.firstIndex(where: { $0 == "habit" || $0 == "habits" }) else { return nil }
        let negations: Set<String> = ["can't", "cant", "cannot", "don't", "dont", "didn't", "didnt", "won't", "wont",
                                      "never", "not", "struggling", "struggle", "hard", "missed", "forgot", "keep", "should"]
        if words.contains(where: { negations.contains($0) }) { return nil }
        let window = words[max(0, habitIndex - 5)..<habitIndex]
        let addVerbs: Set<String> = ["add", "create", "start", "begin", "build", "make", "track", "new", "setup", "set"]
        let editVerbs: Set<String> = ["change", "edit", "update", "rename", "modify", "tweak", "adjust"]
        if window.contains(where: { editVerbs.contains($0) }) { return .edit(target: nil, field: nil, value: nil) }
        if window.contains(where: { addVerbs.contains($0) }) { return .add(name: nil) }
        return nil
    }

    /// Replaces words that look like a typo of "habit(s)" — edit distance 1,
    /// or 2 for h…t words like "hobbit" — and accented forms like "hábit".
    static func normalizeHabitWords(_ text: String) -> String {
        var result = ""
        var token = ""
        func flush() {
            guard !token.isEmpty else { return }
            result += canonicalHabitToken(token) ?? token
            token = ""
        }
        for character in text {
            if character.isLetter {
                token.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }

    static func canonicalHabitToken(_ word: String) -> String? {
        let folded = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        guard folded.count >= 4 else { return nil }
        if folded == "habit" || folded == "habits" {
            return word.lowercased() == folded ? nil : folded
        }
        let excluded: Set<String> = ["abit", "habitat", "habitats", "hasnt", "rabbit", "rabbits", "orbit", "about", "bait", "hobby"]
        guard !excluded.contains(folded) else { return nil }
        let toSingle = editDistance(folded, "habit")
        let toPlural = editDistance(folded, "habits")
        let best = min(toSingle, toPlural)
        let replacement = toPlural < toSingle ? "habits" : "habit"
        if best <= 1 { return replacement }
        if best == 2, folded.hasPrefix("h"), (5...7).contains(folded.count),
           folded.hasSuffix("t") || folded.hasSuffix("ts") {
            return replacement
        }
        return nil
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }

    // MARK: Model safety net

    /// True when a Foundation Models reply wrongly deflects a habit request
    /// ("I can't add habits myself, tap 'add a habit' in the app").
    static func replyDeflectsHabitManagement(_ reply: String) -> Bool {
        let lower = normalizeHabitWords(reply)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        let refusal = #"\b(?:can't|cant|cannot|can not|unable to|not able to|don't have (?:the )?(?:ability|access) to|am not allowed to)\s+(?:\w+\s+){0,3}?(?:add|create|edit|change|make|set up|update|rename|modify|manage|track)\b"#
        if lower.contains("habit"), lower.range(of: refusal, options: .regularExpression) != nil {
            return true
        }
        let tapPrompt = #"\btap\b[^.!?]{0,30}add a habit"#
        if lower.range(of: tapPrompt, options: .regularExpression) != nil { return true }
        return lower.contains("add a habit") && lower.contains("in the app")
    }

    /// Takes over when the model deflected or a request was only loosely
    /// detected: start the add flow (or edit, if the user asked to change).
    static func safetyNetReply(
        forUserText text: String,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply {
        let words = Set(normalizeHabitWords(text).lowercased()
            .components(separatedBy: CharacterSet.letters.inverted))
        let editVerbs: Set<String> = ["change", "edit", "update", "rename", "modify", "tweak", "adjust"]
        if !words.isDisjoint(with: editVerbs), habits.contains(where: \.isEditable) {
            return start(.edit(target: nil, field: nil, value: nil), state: &state, habits: habits)
        }
        state.step = .addName
        return BuddyHabitFlowReply(
            text: "Want to add a habit? What should it be called?",
            quickReplies: nameIdeaChips + [cancelChip]
        )
    }

    // MARK: Edit matching

    /// Case-insensitive exact name match first; otherwise a contains match
    /// ("run" finds "Morning Run" and "Evening Run" — caller asks which one).
    static func matches(for target: String, in habits: [BuddyHabitSnapshot]) -> [BuddyHabitSnapshot] {
        let key = BuddyHabitText.key(cleanTarget(target) ?? target)
        guard !key.isEmpty else { return [] }
        let exact = habits.filter { BuddyHabitText.key($0.name) == key }
        if !exact.isEmpty { return exact }
        guard key.count >= 3 else { return [] }
        return habits.filter {
            let name = BuddyHabitText.key($0.name)
            return name.contains(key) || (name.count >= 3 && key.contains(name))
        }
    }

    // MARK: Starting a flow

    private static func start(
        _ intent: BuddyHabitIntent,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply {
        switch intent {
        case .deleteUnsupported:
            state.reset()
            return BuddyHabitFlowReply(text: deleteUnsupportedText)

        case .add(let name):
            if let name {
                return acceptAddName(name, state: &state, habits: habits)
            }
            state.step = .addName
            return BuddyHabitFlowReply(
                text: "Love that. What habit do you want to build? Tap an idea or type your own.",
                quickReplies: nameIdeaChips + [cancelChip]
            )

        case .edit(let target, let field, let value):
            let active = habits.filter(\.isEditable)
            if let target {
                let found = matches(for: target, in: habits)
                let editable = found.filter(\.isEditable)
                if editable.count == 1 {
                    return proceedEdit(editable[0], field: field, value: value, state: &state, habits: habits)
                }
                if editable.count > 1 {
                    state.step = .editChooseHabit(candidateIDs: editable.map(\.id), field: field, value: value)
                    return BuddyHabitFlowReply(
                        text: "I found a few habits like that. Which one?",
                        quickReplies: habitChips(editable) + [cancelChip]
                    )
                }
                if let archived = found.first {
                    state.reset()
                    return BuddyHabitFlowReply(text: archivedText(archived.name))
                }
                guard !active.isEmpty else {
                    state.reset()
                    return BuddyHabitFlowReply(text: noActiveHabitsText)
                }
                state.step = .editChooseHabit(candidateIDs: active.map(\.id), field: field, value: value)
                return BuddyHabitFlowReply(
                    text: "I couldn\u{2019}t find an active habit called \u{201C}\(target)\u{201D}. Which one did you mean?",
                    quickReplies: habitChips(active) + [cancelChip]
                )
            }
            guard !active.isEmpty else {
                state.reset()
                return BuddyHabitFlowReply(text: noActiveHabitsText)
            }
            state.step = .editChooseHabit(candidateIDs: active.map(\.id), field: field, value: value)
            return BuddyHabitFlowReply(
                text: "Which habit do you want to change?",
                quickReplies: habitChips(active) + [cancelChip]
            )
        }
    }

    // MARK: Continuing a flow

    private static func continueFlow(
        _ text: String,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply? {
        switch state.step {
        case .idle:
            return nil

        case .addName:
            return acceptAddName(text, state: &state, habits: habits)

        case .addTheme(let name):
            guard let theme = HabitTheme.matching(text) else {
                return BuddyHabitFlowReply(
                    text: "Pick one of these themes for \(name):",
                    quickReplies: themeChips() + [cancelChip]
                )
            }
            state.step = .addGoal(name: name, colorHex: theme.hex)
            return askAddGoal(name: name, theme: theme)

        case .addGoal(let name, let colorHex):
            let goal = cleanGoal(text)
            guard !goal.isEmpty else {
                return askAddGoal(name: name, theme: HabitTheme.all.first { $0.hex == colorHex } ?? HabitTheme.defaultTheme)
            }
            state.reset()
            return BuddyHabitFlowReply(
                text: "Here\u{2019}s your new habit. Tap Add to start day 1 today.",
                proposal: addProposal(name: name, colorHex: colorHex, goal: goal)
            )

        case .editChooseHabit(let ids, let field, let value):
            let candidates = habits.filter { ids.contains($0.id) }
            let picked = matches(for: text, in: candidates)
            if picked.count == 1 {
                return proceedEdit(picked[0], field: field, value: value, state: &state, habits: habits)
            }
            return BuddyHabitFlowReply(
                text: "Which one? Tap a habit below.",
                quickReplies: habitChips(candidates) + [cancelChip]
            )

        case .editChooseField(let habitID):
            guard let habit = habits.first(where: { $0.id == habitID }) else {
                state.reset()
                return BuddyHabitFlowReply(text: habitGoneText)
            }
            guard let field = parseField(text) else {
                return BuddyHabitFlowReply(
                    text: "Do you want to change the name, theme or goal of \u{201C}\(habit.name)\u{201D}?",
                    quickReplies: fieldChips + [cancelChip]
                )
            }
            return proceedEdit(habit, field: field, value: nil, state: &state, habits: habits)

        case .editValue(let habitID, let field):
            guard let habit = habits.first(where: { $0.id == habitID }) else {
                state.reset()
                return BuddyHabitFlowReply(text: habitGoneText)
            }
            return applyEdit(habit, field: field, value: text, state: &state, habits: habits)
        }
    }

    private static func acceptAddName(
        _ raw: String,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply {
        let name = canonicalName(cleanTarget(raw) ?? "")
        guard !name.isEmpty else {
            state.step = .addName
            return BuddyHabitFlowReply(
                text: "What should the habit be called?",
                quickReplies: nameIdeaChips + [cancelChip]
            )
        }
        if let existing = habits.first(where: { $0.isEditable && BuddyHabitText.key($0.name) == BuddyHabitText.key(name) }) {
            state.step = .addName
            return BuddyHabitFlowReply(
                text: "You already have an active habit called \u{201C}\(existing.name)\u{201D}. Pick a different name, or say cancel.",
                quickReplies: [cancelChip]
            )
        }
        state.step = .addTheme(name: name)
        return BuddyHabitFlowReply(
            text: "Nice, \(name). Which theme should it have?",
            quickReplies: themeChips() + [cancelChip]
        )
    }

    private static func askAddGoal(name: String, theme: HabitTheme) -> BuddyHabitFlowReply {
        if let suggestion = HabitSuggestionMatcher.suggestion(matching: name) {
            return BuddyHabitFlowReply(
                text: "\(theme.name) it is. What\u{2019}s your goal? Tap the suggestion or type your own.",
                quickReplies: [goalChip(suggestion.description), cancelChip]
            )
        }
        return BuddyHabitFlowReply(
            text: "\(theme.name) it is. What\u{2019}s your goal? For example \u{201C}10 minutes a day\u{201D}.",
            quickReplies: [cancelChip]
        )
    }

    private static func proceedEdit(
        _ habit: BuddyHabitSnapshot,
        field: BuddyHabitField?,
        value: String?,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply {
        guard habit.isEditable else {
            state.reset()
            return BuddyHabitFlowReply(text: archivedText(habit.name))
        }
        guard let field else {
            state.step = .editChooseField(habitID: habit.id)
            return BuddyHabitFlowReply(
                text: "What would you like to change about \u{201C}\(habit.name)\u{201D}?",
                quickReplies: fieldChips + [cancelChip]
            )
        }
        guard let value, !BuddyHabitText.clean(value).isEmpty else {
            state.step = .editValue(habitID: habit.id, field: field)
            return askEditValue(habit, field: field)
        }
        return applyEdit(habit, field: field, value: value, state: &state, habits: habits)
    }

    private static func askEditValue(_ habit: BuddyHabitSnapshot, field: BuddyHabitField) -> BuddyHabitFlowReply {
        switch field {
        case .name:
            return BuddyHabitFlowReply(
                text: "What should I rename \u{201C}\(habit.name)\u{201D} to?",
                quickReplies: [cancelChip]
            )
        case .theme:
            return BuddyHabitFlowReply(
                text: "It\u{2019}s \(HabitTheme.name(forHex: habit.colorHex)) right now. Pick a new theme:",
                quickReplies: themeChips(excluding: habit.colorHex) + [cancelChip]
            )
        case .goal:
            var chips: [BuddyQuickReply] = []
            if let suggestion = HabitSuggestionMatcher.suggestion(matching: habit.name),
               suggestion.description != habit.goal {
                chips.append(goalChip(suggestion.description))
            }
            return BuddyHabitFlowReply(
                text: "The goal is \u{201C}\(habit.goal)\u{201D} right now. What should it be?",
                quickReplies: chips + [cancelChip]
            )
        }
    }

    private static func applyEdit(
        _ habit: BuddyHabitSnapshot,
        field: BuddyHabitField,
        value: String,
        state: inout BuddyHabitFlowState,
        habits: [BuddyHabitSnapshot]
    ) -> BuddyHabitFlowReply {
        var name = habit.name
        var goal = habit.goal
        var colorHex = habit.colorHex

        switch field {
        case .name:
            let newName = cleanNameValue(cleanTarget(value) ?? "")
            guard !newName.isEmpty else {
                state.step = .editValue(habitID: habit.id, field: .name)
                return askEditValue(habit, field: .name)
            }
            if BuddyHabitText.key(newName) == BuddyHabitText.key(habit.name) {
                state.reset()
                return BuddyHabitFlowReply(text: "It\u{2019}s already called \u{201C}\(habit.name)\u{201D}, so nothing to change.")
            }
            if habits.contains(where: { $0.id != habit.id && $0.isEditable && BuddyHabitText.key($0.name) == BuddyHabitText.key(newName) }) {
                state.step = .editValue(habitID: habit.id, field: .name)
                return BuddyHabitFlowReply(
                    text: "You already have a habit called \u{201C}\(newName)\u{201D}. Try another name.",
                    quickReplies: [cancelChip]
                )
            }
            name = newName

        case .theme:
            guard let theme = HabitTheme.matching(value) else {
                state.step = .editValue(habitID: habit.id, field: .theme)
                return BuddyHabitFlowReply(
                    text: "I didn\u{2019}t catch that theme. Pick one:",
                    quickReplies: themeChips(excluding: habit.colorHex) + [cancelChip]
                )
            }
            if theme.hex.caseInsensitiveCompare(habit.colorHex) == .orderedSame {
                state.reset()
                return BuddyHabitFlowReply(text: "\u{201C}\(habit.name)\u{201D} is already \(theme.name).")
            }
            colorHex = theme.hex

        case .goal:
            let newGoal = cleanGoal(value)
            guard !newGoal.isEmpty else {
                state.step = .editValue(habitID: habit.id, field: .goal)
                return askEditValue(habit, field: .goal)
            }
            if newGoal == habit.goal {
                state.reset()
                return BuddyHabitFlowReply(text: "That\u{2019}s already the goal for \u{201C}\(habit.name)\u{201D}.")
            }
            goal = newGoal
        }

        state.reset()
        return BuddyHabitFlowReply(
            text: "Here\u{2019}s the change. Tap Save to apply. Your streak and 21-day cycle stay as they are.",
            proposal: updateProposal(for: habit, name: name, goal: goal, colorHex: colorHex)
        )
    }

    // MARK: Proposals (confirmation card data)

    static func addProposal(name: String, colorHex: String, goal: String) -> BuddyAction {
        BuddyAction(
            type: .addHabit,
            habitName: name,
            habitGoal: goal,
            habitColor: colorHex,
            displayText: "\(name) \u{00B7} \(HabitTheme.name(forHex: colorHex)) \u{00B7} \(goal)"
        )
    }

    static func updateProposal(for habit: BuddyHabitSnapshot, name: String, goal: String, colorHex: String) -> BuddyAction {
        BuddyAction(
            type: .updateHabit,
            habitName: habit.name,
            habitGoal: goal,
            habitColor: colorHex,
            targetHabitID: habit.id,
            displayText: "\(name) \u{00B7} \(HabitTheme.name(forHex: colorHex)) \u{00B7} \(goal)",
            newHabitName: name == habit.name ? nil : name
        )
    }

    // MARK: Quick replies

    static let cancelChip = BuddyQuickReply(label: "Cancel", value: "Cancel", kind: .cancel)

    static var nameIdeaChips: [BuddyQuickReply] {
        HabitSuggestion.all.prefix(6).map { BuddyQuickReply(label: $0.title, value: $0.title) }
    }

    static func themeChips(excluding hex: String? = nil) -> [BuddyQuickReply] {
        HabitTheme.all
            .filter { theme in hex.map { theme.hex.caseInsensitiveCompare($0) != .orderedSame } ?? true }
            .map { BuddyQuickReply(label: $0.name, value: $0.name, colorHex: $0.hex) }
    }

    static var fieldChips: [BuddyQuickReply] {
        BuddyHabitField.allCases.map { BuddyQuickReply(label: $0.label, value: $0.label) }
    }

    static func goalChip(_ description: String) -> BuddyQuickReply {
        BuddyQuickReply(label: description, value: description, kind: .suggestion)
    }

    static func habitChips(_ habits: [BuddyHabitSnapshot]) -> [BuddyQuickReply] {
        habits.prefix(8).map { BuddyQuickReply(label: $0.name, value: $0.name, colorHex: $0.colorHex) }
    }

    // MARK: Copy

    static let deleteUnsupportedText = "I can\u{2019}t delete habits from chat. Long-press the habit on Home and choose Delete."
    static let noActiveHabitsText = "You don\u{2019}t have any active habits to edit yet. Say \u{201C}add a habit\u{201D} and I\u{2019}ll set one up."
    static let habitGoneText = "I can\u{2019}t find that habit anymore, so I didn\u{2019}t change anything."

    static func archivedText(_ name: String) -> String {
        "\u{201C}\(name)\u{201D} has finished its 21-day cycle, so it\u{2019}s read-only now. Want to start a new habit instead?"
    }

    // MARK: Helpers

    private static func takesFreeText(_ step: BuddyHabitFlowStep) -> Bool {
        switch step {
        case .addName, .addGoal:
            return true
        case .editValue(_, let field):
            return field != .theme
        default:
            return false
        }
    }

    static func isCancel(_ text: String) -> Bool {
        let key = BuddyHabitText.key(text)
        let phrases = ["cancel", "cancel that", "never mind", "nevermind", "forget it", "stop", "quit", "exit", "no thanks", "nope"]
        return phrases.contains(key) || key.hasPrefix("cancel ")
    }

    private static func parseField(_ text: String) -> BuddyHabitField? {
        let key = BuddyHabitText.key(text)
        if key.contains("theme") || key.contains("colo") || key.contains("background") { return .theme }
        if key.contains("goal") || key.contains("description") || key.contains("target") { return .goal }
        if key.contains("name") || key.contains("call") || key.contains("title") { return .name }
        return nil
    }

    private static func stripPoliteness(_ text: String) -> String {
        var result = text
        let pattern = #"^(?:please|pls|plz|can\s+you|could\s+you|would\s+you|will\s+you|can\s+u|kindly|hey|hi|ok|okay|so|buddy)[,!\s]+"#
        while let range = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            result.removeSubrange(range)
        }
        if let range = result.range(of: #"[,\s]+please$"#, options: [.regularExpression, .caseInsensitive]) {
            result.removeSubrange(range)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips "my", "the", trailing "habit", possessives. nil if nothing specific is left.
    static func cleanTarget(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var text = BuddyHabitText.clean(raw)
        let leading = #"^(?:my|the|a|an|this|that|our)\s+"#
        while let range = text.range(of: leading, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        if let range = text.range(of: #"\s+habits?$"#, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        if let range = text.range(of: #"(?:'s|’s)$"#, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        text = BuddyHabitText.clean(text)
        let vague = ["", "habit", "habits", "one", "it", "something", "new habit", "a habit"]
        return vague.contains(text.lowercased()) ? nil : text
    }

    /// Exact suggestion title, else a stem match ("meditating" -> "Meditate"),
    /// else the user's text with a capital first letter.
    static func canonicalName(_ raw: String) -> String {
        let name = BuddyHabitText.clean(raw)
        guard !name.isEmpty else { return "" }
        if let exact = HabitSuggestionMatcher.suggestion(matching: name) { return exact.title }
        let words = stems(of: name)
        if let stemMatch = HabitSuggestion.all.first(where: { suggestion in
            let titleWords = stems(of: suggestion.title)
            guard titleWords.count == words.count else { return false }
            return zip(titleWords, words).allSatisfy { a, b in
                a == b || (min(a.count, b.count) >= 4 && (a.hasPrefix(b) || b.hasPrefix(a)))
            }
        }) {
            return stemMatch.title
        }
        return capitalizedFirst(name)
    }

    /// For renames: only an exact suggestion title is canonicalised.
    private static func cleanNameValue(_ raw: String) -> String {
        let name = BuddyHabitText.clean(raw)
        guard !name.isEmpty else { return "" }
        return HabitSuggestionMatcher.suggestion(matching: name)?.title ?? capitalizedFirst(name)
    }

    /// Goals keep their own punctuation (suggestion descriptions end in ".").
    static func cleanGoal(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func stems(of text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { word in
                var w = word
                if w.hasSuffix("ation"), w.count > 7 { w.removeLast(5) }
                else if w.hasSuffix("ing"), w.count > 5 {
                    w.removeLast(3)
                    // running -> runn -> run
                    if w.count >= 2, let last = w.last, w.dropLast().last == last, !"aeiou".contains(last) {
                        w.removeLast()
                    }
                }
                return w
            }
    }

    private static func captures(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<max(match.numberOfRanges, 1)).map { index in
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
            let value = BuddyHabitText.clean(String(text[swiftRange]))
            return value.isEmpty ? nil : value
        } + [nil, nil, nil]
    }
}

enum BuddyHabitText {
    private static let edgeCharacters = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}`")
        .union(.whitespacesAndNewlines)

    static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: edgeCharacters)
        while let last = result.last, ".!?,;:".contains(last) {
            result.removeLast()
            result = result.trimmingCharacters(in: edgeCharacters)
        }
        return result
    }

    static func key(_ text: String) -> String {
        clean(text).lowercased()
    }
}

// MARK: - Execution (the ONLY place chat changes habits)

/// What Buddy can do to the habit list. HabitViewModel conforms, so chat
/// edits go through the exact same add/update path as the Add/Edit screens.
protocol BuddyHabitStore: AnyObject {
    var habits: [Habit] { get }
    func addHabit(_ habit: Habit)
    func updateHabit(_ habit: Habit)
}

extension HabitViewModel: BuddyHabitStore {}

enum BuddyHabitExecutionOutcome: Equatable {
    case added(UUID)
    case updated(UUID)
    case notConfirmed
    case habitNotFound
    case archived
    case unsupported
    case invalid

    var succeeded: Bool {
        switch self {
        case .added, .updated: return true
        default: return false
        }
    }
}

enum BuddyHabitActionExecutor {
    /// Applies a proposal only after the user tapped confirm. Edits never
    /// touch startDate / completions / freezes, so the 21-day cycle and
    /// streak carry on. Delete is refused.
    static func execute(
        _ action: BuddyAction,
        status: ActionStatus,
        store: BuddyHabitStore,
        userId: UUID?,
        now: Date = Date()
    ) -> BuddyHabitExecutionOutcome {
        guard status == .confirmed else { return .notConfirmed }

        switch action.type {
        case .deleteHabit:
            return .unsupported

        case .addHabit:
            let name = BuddyHabitText.clean(action.habitName)
            let goal = BuddyHabitFlow.cleanGoal(action.habitGoal ?? "")
            guard !name.isEmpty, !goal.isEmpty else { return .invalid }
            // Same shape as AddHabitView.addHabit() (no reminder from chat).
            let habit = Habit(
                name: name,
                goal: goal,
                color: action.habitColor ?? HabitTheme.defaultTheme.hex,
                startDate: now,
                userId: userId,
                syncStatus: .pending
            )
            store.addHabit(habit)
            return .added(habit.id)

        case .updateHabit:
            guard let targetID = action.targetHabitID,
                  let habit = store.habits.first(where: { $0.id == targetID }) else {
                return .habitNotFound
            }
            // Check before mutating: the Habit is a shared reference.
            guard habit.isInActiveCycle else { return .archived }
            if let newName = action.newHabitName.map({ BuddyHabitText.clean($0) }), !newName.isEmpty {
                habit.name = newName
            }
            if let goal = action.habitGoal.map({ BuddyHabitFlow.cleanGoal($0) }), !goal.isEmpty {
                habit.goal = goal
            }
            if let color = action.habitColor, !color.isEmpty {
                habit.color = color
            }
            habit.updatedAt = now
            habit.syncStatus = .pending
            store.updateHabit(habit)
            return .updated(habit.id)
        }
    }

    /// Buddy's short reply after the card was confirmed.
    static func followUpText(for action: BuddyAction, outcome: BuddyHabitExecutionOutcome) -> String {
        let finalName = action.newHabitName ?? action.habitName
        switch outcome {
        case .added:
            return "Done! \u{201C}\(action.habitName)\u{201D} is on your list. Day 1 starts today."
        case .updated:
            return "Saved! \u{201C}\(finalName)\u{201D} is updated. Your streak and 21-day cycle are untouched."
        case .archived:
            return BuddyHabitFlow.archivedText(action.habitName)
        case .habitNotFound:
            return BuddyHabitFlow.habitGoneText
        case .unsupported:
            return BuddyHabitFlow.deleteUnsupportedText
        case .notConfirmed, .invalid:
            return "Hmm, something went wrong, so I didn\u{2019}t change anything."
        }
    }
}
