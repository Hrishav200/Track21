//
//  Track21App.swift
//  Track21
//
//  Created by Hrishav Sunar on 8/10/2025.
//

import SwiftUI

@main
struct Track21App: App {
    @State private var authService = AuthService()
    @State private var viewModel = HabitViewModel()
    @State private var profileService = ProfileService()
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
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
                    try await SupabaseConfig.client.auth.session(from: url)
                    await authService.checkSession()
                } catch {
                    print("Deep link auth error: \(error)")
                }
            }
        }
    }
}
