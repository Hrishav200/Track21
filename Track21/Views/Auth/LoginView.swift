//
//  LoginView.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//

import SwiftUI

struct LoginView: View {
    private enum Field {
        case email, fullName, password
    }

    @Bindable var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isSignUp = false
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var isResetting = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                backgroundBlobs

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                            heroSection
                            valuePropsRow

                            formSection
                                .padding(.horizontal, 24)

                            trustFooter
                        }
                        .padding(.top, 48)
                        .padding(.bottom, 32)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) {
                        guard let focusedField else { return }
                        // Deferred a tick so the keyboard's safe-area inset
                        // has actually applied before scrolling — scrolling
                        // in the same run-loop pass as the focus change can
                        // land short and leave the field under the keyboard.
                        DispatchQueue.main.async {
                            withAnimation {
                                proxy.scrollTo(focusedField, anchor: .center)
                            }
                        }
                    }
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

    // MARK: - Decorative background

    /// Soft, blurred brand-color blobs behind the hero — gives the screen
    /// depth instead of a flat fill, without needing any bitmap assets.
    private var backgroundBlobs: some View {
        ZStack {
            Circle()
                .fill(AppTheme.primary.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -140, y: -300)

            Circle()
                .fill(AppTheme.primary.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: 150, y: -140)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Hero

    /// A badge that mirrors the app's own icon (the 21-day streak grid)
    /// instead of a generic system glyph, so the login screen carries the
    /// same brand mark as the home screen.
    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppTheme.primary)
                    .frame(width: 112, height: 112)
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 20, x: 0, y: 10)

                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        streakCell(checked: false)
                        streakCell(checked: false)
                    }
                    HStack(spacing: 7) {
                        streakCell(checked: false)
                        streakCell(checked: true)
                    }
                }
            }

            Text("Track21")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Build habits in 21 days")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func streakCell(checked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(checked ? Color.white : Color.white.opacity(0.35))
            .frame(width: 24, height: 24)
            .overlay {
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                }
            }
    }

    // MARK: - Value props

    private var valuePropsRow: some View {
        HStack(spacing: 0) {
            valueProp(icon: "flame.fill", label: "Build\nstreaks")
            valueProp(icon: "chart.bar.fill", label: "Track\nprogress")
            valueProp(icon: "target", label: "21-day\nmethod")
        }
        .padding(.horizontal, 24)
    }

    private func valueProp(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.replacingOccurrences(of: "\n", with: " "))
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .email)
                .id(Field.email)

            if isSignUp {
                TextField("Full Name", text: $fullName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .fullName)
                    .id(Field.fullName)
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .id(Field.password)

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
    }

    // MARK: - Footer

    private var trustFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Your habits stay private — sign in anytime to back them up")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 40)
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
