//
//  SupabaseConfig.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import Foundation
import Supabase

enum SupabaseConfig {
    // swiftlint:disable:next force_unwrapping
    static let url = URL(string: "https://typupewbtivudhcunxme.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5cHVwZXdidGl2dWRoY3VueG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1NTEyNjcsImV4cCI6MjA4NTEyNzI2N30.A7iW0lnI0HKwxQ8hjYAU60J5DQKYCp8Y1IhGv1d_-tE"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
