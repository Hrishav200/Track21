//
//  Track21App.swift
//  Track21
//
//  Created by Hrishav Sunar on 8/10/2025.
//

import SwiftUI

@main
struct Track21App: App {
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView(authService: authService)
            } else {
                LoginView(authService: authService)
            }
        }
        .modelContainer(for: Habit.self)
    }
}
