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
    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            // No stored session or expired — stay on login screen
            currentUser = nil
        }
    }
    
    func signUp(email: String, password: String, fullName: String) async throws {
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

            // Create the user profile — username defaults to email prefix
            let userId = response.user.id
            let profileService = ProfileService()
            let defaultUsername = email.components(separatedBy: "@").first ?? email

            // Create profile with full name and email-based username
            _ = try await profileService.createProfile(
                userId: userId,
                username: defaultUsername,
                fullName: fullName.isEmpty ? nil : fullName
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
        // Get the current session token
        let session = try await supabase.auth.session
        let accessToken = session.accessToken

        // Call the server-side Edge Function to delete all user data
        let functionURL = SupabaseConfig.url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("delete-account")

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Track21", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Account deletion failed (\(statusCode)): \(body)"])
        }

        // Server-side deletion succeeded; clear local state
        currentUser = nil
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
