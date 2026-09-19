//
//  JournalService.swift
//  Track21
//
//  Owns journal entries — an append-only log (multiple entries per day are
//  allowed; saving never overwrites a previous entry, only `update(id:...)`
//  does, and only for the one entry the caller explicitly opened to edit).
//  UserDefaults-backed, same singleton + JSON-array pattern as BuddyService's
//  chat history.
//

import Foundation

@Observable
final class JournalService {
    static let shared = JournalService()

    private let entriesKey = "Track21JournalEntries"

    /// All entries, most recent first. Multiple entries can share a
    /// calendar day — JournalLogic's streak calc groups by day, not by
    /// entry count.
    private(set) var entries: [JournalEntry] = []

    private init() {
        load()
    }

    /// Always creates a brand-new entry — this is the "Save Entry" action,
    /// never an overwrite of whatever you last wrote today.
    @discardableResult
    func add(text: String, mood: JournalMood?, date: Date = Date(), userId: UUID? = nil) -> JournalEntry {
        let newEntry = JournalEntry(date: date, text: text, mood: mood, userId: userId)
        entries.insert(newEntry, at: 0)
        entries.sort { $0.createdAt > $1.createdAt }
        persist()
        return newEntry
    }

    /// Updates one specific entry by id — used only when the user has
    /// explicitly opened that entry (via the "All Entries" list) to edit it.
    func update(id: UUID, text: String, mood: JournalMood?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].text = text
        entries[index].mood = mood
        entries[index].updatedAt = Date()
        persist()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clearData() {
        entries = []
        UserDefaults.standard.removeObject(forKey: entriesKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }
}
