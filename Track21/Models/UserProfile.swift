//
//  UserProfile.swift
//  Track21
//
//  Created by Hrishav Sunar on 5/2/2026.
//

import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var username: String
    var fullName: String?
    var avatarUrl: String?
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID, username: String, fullName: String? = nil, avatarUrl: String? = nil) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.createdAt = Date()
        self.updatedAt = nil
    }
}
