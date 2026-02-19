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
    var isAuthenticated: Bool { currentUser != nil || isGuest }
    var isGuest = false
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseConfig.client
    private static let hasLaunchedKey = "Track21HasLaunched"

    func checkSession() async {
        // If the app was deleted and reinstalled, the Keychain still holds the old
        // session but UserDefaults is wiped. Detect this and clear the stale session.
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: Self.hasLaunchedKey)
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
            try? await supabase.auth.signOut()
            currentUser = nil
            return
        }

        // Use a timeout so the UI doesn't freeze on slow networks
        do {
            let session = try await withThrowingTaskGroup(of: User.self) { group in
                group.addTask {
                    let session = try await self.supabase.auth.session
                    return session.user
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                    throw CancellationError()
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            currentUser = session
        } catch {
            currentUser = nil
        }
    }
    
    func signUp(email: String, password: String, fullName: String) async throws {
        isLoading = true
        errorMessage = nil

        let defaultUsername = email.components(separatedBy: "@").first ?? email

        do {
            // Sign up with metadata so the Supabase trigger can populate the profile
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "username": .string(defaultUsername),
                    "full_name": .string(fullName)
                ]
            )

            // Check if this is a genuinely new user
            // Supabase returns an empty identities array if the email already exists
            guard let identities = response.user.identities, !identities.isEmpty else {
                isLoading = false
                errorMessage = "An account with this email already exists. Please sign in."
                throw NSError(domain: "Track21", code: 409, userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists. Please sign in."])
            }

            currentUser = response.user

            // Also upsert the profile in case the trigger didn't set all fields
            let userId = response.user.id
            let profileService = ProfileService()
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
    
    func continueAsGuest() {
        isGuest = true
    }

    func signOut() async throws {
        if isGuest {
            isGuest = false
            return
        }
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
