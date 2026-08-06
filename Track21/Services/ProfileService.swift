//
//  ProfileService.swift
//  Track21
//
//  Created by Hrishav Sunar on 5/2/2026.
//

import Foundation
import Supabase

@Observable
class ProfileService {
    var currentProfile: UserProfile?
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseConfig.client
    
    /// Fetch user profile from Supabase
    func fetchProfile(userId: UUID) async throws -> UserProfile? {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            currentProfile = profiles.first
            return currentProfile
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Create or update a profile for user (upsert handles auto-created rows from triggers)
    func createProfile(userId: UUID, username: String, fullName: String? = nil) async throws -> UserProfile {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let profile = UserProfile(id: userId, username: username, fullName: fullName)

        do {
            try await supabase
                .from("profiles")
                .upsert(profile)
                .execute()

            currentProfile = profile
            return profile
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Update existing profile
    func updateProfile(userId: UUID, username: String? = nil, fullName: String? = nil) async throws -> UserProfile {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        var updates: [String: AnyJSON] = [
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let username = username {
            updates["username"] = .string(username)
        }
        
        if let fullName = fullName {
            updates["full_name"] = .string(fullName)
        }
        
        do {
            let updated: [UserProfile] = try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId)
                .select()
                .execute()
                .value
            
            if let profile = updated.first {
                currentProfile = profile
                return profile
            } else {
                throw ProfileError.notFound
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Check if username is available
    func isUsernameAvailable(_ username: String, excludingUserId: UUID? = nil) async throws -> Bool {
        let profiles: [UserProfile] = try await supabase
            .from("profiles")
            .select()
            .eq("username", value: username)
            .execute()
            .value
        
        if let excludeId = excludingUserId {
            return profiles.isEmpty || profiles.allSatisfy { $0.id == excludeId }
        }
        
        return profiles.isEmpty
    }
}

enum ProfileError: LocalizedError {
    case notFound
    case usernameTaken
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Profile not found"
        case .usernameTaken:
            return "Username is already taken"
        }
    }
}
