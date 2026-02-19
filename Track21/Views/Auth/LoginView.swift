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
    @State private var fullName = ""
    @State private var isSignUp = false
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var isResetting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.primary)
                            .accessibilityHidden(true)

                        Text("Track21")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Build habits in 21 days")
                            .font(.subheadline)
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

                        if isSignUp {
                            TextField("Full Name", text: $fullName)
                                .textFieldStyle(.roundedBorder)
                        }

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(action: {
                            Task {
                                try? await (isSignUp ? authService.signUp(email: email, password: password, fullName: fullName) : authService.signIn(email: email, password: password))
                            }
                        }) {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (isSignUp && fullName.isEmpty))

                        // Forgot password (only show on sign in)
                        if !isSignUp {
                            Button(action: {
                                resetEmail = email
                                showingResetPassword = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            isSignUp.toggle()
                            fullName = ""
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.primary)
                        }

                        Button(action: {
                            authService.continueAsGuest()
                        }) {
                            Text("Continue as Guest")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingResetPassword) {
            ResetPasswordSheet(
                email: $resetEmail,
                message: $resetMessage,
                isResetting: $isResetting,
                authService: authService,
                isPresented: $showingResetPassword
            )
        }
    }
}

// MARK: - Reset Password Sheet

struct ResetPasswordSheet: View {
    @Binding var email: String
    @Binding var message: String?
    @Binding var isResetting: Bool
    var authService: AuthService
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.primary)
                            .accessibilityHidden(true)

                        Text("Reset Password")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Enter your email and we'll send you a link to reset your password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        if let msg = message {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundColor(msg.contains("sent") ? AppTheme.primary : .red)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: resetPassword) {
                            if isResetting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send Reset Link")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isResetting || email.isEmpty)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func resetPassword() {
        isResetting = true
        message = nil
        
        Task {
            do {
                try await authService.resetPassword(email: email)
                message = "Reset link sent! Check your email."
                
                // Auto-dismiss after success
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                isPresented = false
            } catch {
                message = error.localizedDescription
            }
            isResetting = false
        }
    }
}
