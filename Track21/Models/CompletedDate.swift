//
//  CompletedDate.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation

struct CompletedDate: Codable, Identifiable {
    let id: UUID
    let habitId: UUID
    let completedDate: Date
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case completedDate = "completed_date"
        case createdAt = "created_at"
    }
}
