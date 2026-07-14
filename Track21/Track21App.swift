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

    init() {
        // As early as possible — without this, a reminder that fires while
        // the app happens to be in the foreground is silently dropped.
        NotificationService.shared.registerAsDelegate()
    }

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
            .task {
                // UI tests launch with this flag so each test starts from a
                // clean slate instead of accumulating habits across runs.
                if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
                    viewModel.clearData()
                    BuddyService.shared.clearData()
                    // Pre-name the buddy so the one-time naming screen
                    // doesn't block every other UI test's path to the home
                    // screen. Tests that specifically exercise onboarding
                    // pass -uitest-fresh-buddy to skip this and see it.
                    if !ProcessInfo.processInfo.arguments.contains("-uitest-fresh-buddy") {
                        BuddyService.shared.saveBuddyName("Buddy")
                    }
                }

                // Seeds a habit with a mix of completed/frozen/missed days so
                // the streak-freeze UI (journey grid, weekly calendar) can be
                // screenshotted without waiting for a real missed day.
                if ProcessInfo.processInfo.arguments.contains("-uitest-seed-frozen-habit") {
                    let calendar = Calendar.current
                    let startDate = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
                    let habit = Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF", startDate: startDate)
                    habit.completedDates = [6, 5, 3, 1].compactMap {
                        calendar.date(byAdding: .day, value: -$0, to: Date())
                    }
                    if let frozenDay = calendar.date(byAdding: .day, value: -4, to: Date()) {
                        habit.frozenDates = [frozenDay]
                    }
                    viewModel.addHabit(habit)
                }

                // Check for existing session after the UI is already rendered
                await authService.checkSession()
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
