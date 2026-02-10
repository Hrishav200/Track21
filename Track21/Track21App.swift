//
//  Track21App.swift
//  Track21
//
//  Created by Hrishav Sunar on 8/10/2025.
//

import SwiftUI
import Supabase
internal import Auth

@main
struct Track21App: App {
    @State private var authService = AuthService()
    @State private var viewModel = HabitViewModel()
    @State private var profileService = ProfileService()
    @State private var showPasswordReset = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showPasswordReset {
                    PasswordResetView(isPresented: $showPasswordReset)
                } else if authService.isAuthenticated {
                    ContentView(
                        authService: authService,
                        viewModel: viewModel,
                        profileService: profileService
                    )
                } else {
                    LoginView(authService: authService)
                }
            }
            .onOpenURL { url in
                // Handle deep links for auth (password reset, magic links, etc.)
                Task {
                    do {
                        // Check if this is a password reset link
                        let urlString = url.absoluteString
                        if urlString.contains("reset-password") || urlString.contains("type=recovery") {
                            // Process the recovery session
                            try await SupabaseConfig.client.auth.session(from: url)
                            // Show password reset screen
                            showPasswordReset = true
                        } else {
                            // Handle other auth links (magic links, etc.)
                            try await SupabaseConfig.client.auth.session(from: url)
                            await authService.checkSession()
                        }
                    } catch {
                        // Deep link auth error handled silently
                    }
                }
            }
        }
    }
}
