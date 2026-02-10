//
//  AuthService.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import Supabase
import AuthenticationServices

@Observable
class AuthService {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseConfig.client
    
    init() {
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, sign up with Supabase Auth
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            // Check if this is a genuinely new user
            // Supabase returns an empty identities array if the email already exists
            // (to prevent email enumeration attacks)
            guard let identities = response.user.identities, !identities.isEmpty else {
                isLoading = false
                errorMessage = "An account with this email already exists. Please sign in."
                throw NSError(domain: "Track21", code: 409, userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists. Please sign in."])
            }

            currentUser = response.user

            // Then, create the user profile with username
            let userId = response.user.id
            let profileService = ProfileService()
            
            // Check if username is available
            let isAvailable = try await profileService.isUsernameAvailable(username)
            guard isAvailable else {
                errorMessage = "Username is already taken"
                isLoading = false
                throw NSError(domain: "Track21", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
            }
            
            // Create profile
            _ = try await profileService.createProfile(
                userId: userId,
                username: username
            )
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            currentUser = session.user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
    }

    func deleteAccount() async throws {
        // Call the server-side Edge Function to delete all user data
        // (completed_dates, habits, profiles, and the auth user)
        try await supabase.functions.invoke("delete-account")

        // Server-side deletion succeeded; clear local state
        currentUser = nil
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
