//
//  JournalEntry.swift
//  Track21
//
//  One reflection per calendar day — freeform text plus an optional mood.
//  Local-only for now (same reasoning as Habit's reminderTime/frozenDates):
//  no journal_entries table/sync exists yet, so entries don't cross devices.
//

import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var date: Date
    var text: String
    var mood: JournalMood?
    var userId: UUID?
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String = "",
        mood: JournalMood? = nil,
        userId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.mood = mood
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum JournalMood: String, Codable, CaseIterable, Identifiable {
    case great, good, okay, rough, bad

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good: return "🙂"
        case .okay: return "😐"
        case .rough: return "😕"
        case .bad: return "😞"
        }
    }

    var label: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .okay: return "Okay"
        case .rough: return "Rough"
        case .bad: return "Bad"
        }
    }
}
