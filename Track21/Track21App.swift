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
    }
}
