//
//  LoginView.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import SwiftUI

struct LoginView: View {
    @Bindable var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F5F5F5").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "5DD167"))
                        
                        Text("Track21")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("Build habits in 21 days")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                        
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            Task {
                                try? await (isSignUp ? authService.signUp(email: email, password: password) : authService.signIn(email: email, password: password))
                            }
                        }) {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "5DD167"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                        
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "5DD167"))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
        }
    }
}
