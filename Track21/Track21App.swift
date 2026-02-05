//
//  Track21App.swift
//  Track21
//
//  Created by Hrishav Sunar on 8/10/2025.
//

import SwiftUI
import SwiftData

@main
struct Track21App: App {
    
    let authService = AuthService()
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView(authService: authService)
            } else {
                LoginView(authService: authService)
            }
        }
        .modelContainer(for: [Habit.self])
    }
}
