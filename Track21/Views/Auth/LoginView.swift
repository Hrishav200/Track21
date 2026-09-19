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
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 28) {
                                Spacer(minLength: 24)

                                heroSection

                                formSection
                                    .padding(.horizontal, 24)

                                Spacer(minLength: 24)
                            }
                            // A plain offset rather than uneven Spacer
                            // minLengths — two Spacers with surplus flex
                            // space split it evenly regardless of their
                            // minLengths, so biasing the split that way
                            // doesn't actually move anything. This nudges
                            // the already-centered content up by a fixed
                            // amount instead.
                            .offset(y: -36)
                            // Stretch to fill the screen so the two Spacers
                            // can center the content — while still letting
                            // the ScrollView do its normal job if the
                            // keyboard shrinks the available room below that.
                            .frame(minHeight: geometry.size.height)
                            .padding(.vertical, 32)
                        }
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
    /// same brand mark as the home screen. Deliberately compact — the value
    /// props row and trust-footer sentence that used to sit below this were
    /// cut entirely: the onboarding carousel right after sign-in already
    /// covers "build streaks / track progress / 21-day method", so login
    /// doesn't need to sell the app again before letting someone in.
    private var heroSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.primary)
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 14, x: 0, y: 6)

                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        streakCell(checked: false)
                        streakCell(checked: false)
                    }
                    HStack(spacing: 5) {
                        streakCell(checked: false)
                        streakCell(checked: true)
                    }
                }
            }

            Text("Track21")
                .font(.title2)
                .fontWeight(.bold)
        }
    }

    @ViewBuilder
    private func streakCell(checked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(checked ? Color.white : Color.white.opacity(0.35))
            .frame(width: 16, height: 16)
            .overlay {
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                }
            }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .authFieldStyle()
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .email)
                .id(Field.email)

            if isSignUp {
                TextField("Full Name", text: $fullName)
                    .authFieldStyle()
                    .focused($focusedField, equals: .fullName)
                    .id(Field.fullName)
            }

            SecureField("Password", text: $password)
                .authFieldStyle()
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
            .buttonStyle(.plain)
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
                .buttonStyle(.plain)
            }

            Button(action: {
                isSignUp.toggle()
                fullName = ""
            }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.primary)
            }
            .buttonStyle(.plain)

            Button(action: {
                authService.continueAsGuest()
            }) {
                Text("Continue as Guest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

private extension View {
    /// Replaces `.textFieldStyle(.roundedBorder)`, whose default fill reads
    /// as near-invisible against this app's dark-mode background (barely
    /// distinguishable black-on-near-black). Uses the same card-surface
    /// color as every other input field in the app, so it stays legible in
    /// both themes instead of relying on the system default.
    func authFieldStyle() -> some View {
        self
            .padding(12)
            .background(AppTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
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
                            .authFieldStyle()
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
                        .buttonStyle(.plain)
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
