//
//  JournalService.swift
//  Track21
//
//  Owns journal entries — one per calendar day, UserDefaults-backed, same
//  singleton + JSON-array pattern as BuddyService's chat history.
//

import Foundation

@Observable
final class JournalService {
    static let shared = JournalService()

    private let entriesKey = "Track21JournalEntries"

    /// All entries, most recent day first.
    private(set) var entries: [JournalEntry] = []

    private init() {
        load()
    }

    var todaysEntry: JournalEntry? {
        entry(for: Date())
    }

    func entry(for date: Date, calendar: Calendar = .current) -> JournalEntry? {
        let day = calendar.startOfDay(for: date)
        return entries.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Creates or updates the entry for the given day. Empty text with no
    /// mood is still saved as a valid (blank) entry — the caller decides
    /// whether that's worth doing (JournalView disables Save in that case).
    @discardableResult
    func save(text: String, mood: JournalMood?, for date: Date = Date(), userId: UUID? = nil) -> JournalEntry {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)

        if let index = entries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            entries[index].text = text
            entries[index].mood = mood
            entries[index].updatedAt = Date()
            let updated = entries[index]
            persist()
            return updated
        }

        let newEntry = JournalEntry(date: day, text: text, mood: mood, userId: userId)
        entries.append(newEntry)
        entries.sort { $0.date > $1.date }
        persist()
        return newEntry
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
            entries = decoded.sorted { $0.date > $1.date }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }
}
