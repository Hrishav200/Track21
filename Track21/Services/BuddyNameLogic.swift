//
//  BuddyNameLogic.swift
//  Track21
//
//  Validation for the accountability buddy's name, shared by first-launch
//  naming, the Rename Buddy sheet (Profile + chat header) and the chat
//  "call yourself X" flow.
//

import Foundation

enum BuddyNameLogic {
    static let maxLength = 24
    static let defaultName = "Buddy"

    enum Validation: Equatable {
        case valid(String)
        case empty
        case tooLong
    }

    /// Trims, drops surrounding quotes and collapses inner whitespace/newlines.
    static func sanitize(_ raw: String) -> String {
        let quotes = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}`")
        return raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: quotes.union(.whitespaces))
    }

    static func validate(_ raw: String) -> Validation {
        let name = sanitize(raw)
        if name.isEmpty { return .empty }
        if name.count > maxLength { return .tooLong }
        return .valid(name)
    }

    static func errorMessage(for validation: Validation) -> String? {
        switch validation {
        case .valid: return nil
        case .empty: return "Give your buddy a name."
        case .tooLong: return "Keep it to \(maxLength) characters or fewer."
        }
    }

    /// True when `raw` is a valid name that differs from `current` (case-sensitive,
    /// so "max" -> "Max" counts as a change).
    static func isChange(_ raw: String, from current: String?) -> Bool {
        guard case .valid(let name) = validate(raw) else { return false }
        return name != current
    }
}
