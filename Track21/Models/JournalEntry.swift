//
//  JournalEntry.swift
//  Track21
//
//  A single journal entry — freeform text plus optional mood & energy.
//  Multiple entries can share a calendar day (JournalService.add never
//  overwrites a previous one); `date` marks which day an entry belongs to
//  for streak purposes, `createdAt` is the actual moment it was written.
//  Local-only for now (same reasoning as Habit's reminderTime/frozenDates):
//  no journal_entries table/sync exists yet, so entries don't cross devices.
//

import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var date: Date
    var text: String
    var mood: JournalMood?
    /// Subjective energy 1…5. Optional so older persisted entries still decode.
    var energy: Int?
    var userId: UUID?
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String = "",
        mood: JournalMood? = nil,
        energy: Int? = nil,
        userId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.mood = mood
        self.energy = energy.map { min(5, max(1, $0)) }
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

    /// Soft tint used on timeline nodes and composer accents.
    var tintHex: String {
        switch self {
        case .great: return "5DD167"
        case .good: return "8FD99A"
        case .okay: return "FFD166"
        case .rough: return "FFB347"
        case .bad: return "FF8A80"
        }
    }
}
