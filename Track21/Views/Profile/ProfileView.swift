//
//  ProfileView.swift
//  Track21
//
//  Created by Hrishav Sunar on 5/2/2026.
//

import SwiftUI
internal import Auth

struct ProfileView: View {
    @Bindable var authService: AuthService
    @Bindable var profileService: ProfileService
    @Bindable var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingPaywall = false
    @State private var paywallTrigger: PaywallView.Trigger = .general
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile avatar
                        VStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(initials)
                                        .font(.largeTitle.weight(.bold))
                                        .foregroundColor(AppTheme.primary)
                                )
                                .accessibilityLabel("Profile avatar: \(initials)")

                            if let email = authService.currentUser?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        // Profile form
                        VStack(spacing: 16) {
                            ProfileTextField(
                                title: "Username",
                                text: $username,
                                placeholder: "Enter username",
                                isEditing: isEditing
                            )

                            ProfileTextField(
                                title: "Full Name",
                                text: $fullName,
                                placeholder: "Enter your name",
                                isEditing: isEditing
                            )
                        }
                        .padding(.horizontal, 24)

                        // Messages
                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }

                        if let success = successMessage {
                            Text(success)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.primary)
                                .padding(.horizontal, 24)
                        }

                        // Action buttons
                        VStack(spacing: 12) {
                            if isEditing {
                                Button(action: saveProfile) {
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Save Changes")
                                            .font(.body.weight(.semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .disabled(isSaving || username.isEmpty)

                                Button("Cancel") {
                                    cancelEditing()
                                }
                                .font(.body.weight(.medium))
                                .foregroundColor(.secondary)
                            } else {
                                Button(action: { isEditing = true }) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit Profile")
                                    }
                                    .font(.body.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .accessibilityLabel("Edit Profile")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Upgrade card (hidden once already Pro)
                        if !viewModel.isPremium {
                            upgradeCard
                                .padding(.horizontal, 24)
                        }

                        // Streak freeze wallet
                        freezeWalletCard
                            .padding(.horizontal, 24)

                        #if DEBUG
                        Button(action: { showingDebugMenu = true }) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                Text("Debug Menu")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        #endif

                        // Privacy policy link
                        Link(destination: URL(string: "https://hrishav200.github.io/Track21/privacy/")!) {
                            HStack {
                                Image(systemName: "hand.raised")
                                Text("Privacy Policy")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 40)

                        // Sign out button
                        Button(action: { showingSignOutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.red)
                        }
                        .accessibilityLabel("Sign Out")

                        // Delete account button
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.red.opacity(0.8))
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                        .accessibilityLabel("Delete Account")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all your data. This action cannot be undone.")
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView(viewModel: viewModel, authService: authService)
            }
            #endif
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: paywallTrigger)
            }
            .task {
                await loadProfile()
            }
        }
    }

    private var upgradeCard: some View {
        Button(action: {
            paywallTrigger = .general
            showingPaywall = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "crown.fill")
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Unlimited freezes, unlimited chat, full history")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding(16)
            .background(AppTheme.primary)
            .cornerRadius(16)
        }
        .accessibilityLabel("Go Pro")
        .accessibilityHint("Opens the Track21 Pro upgrade screen")
    }
    
    private var freezeWalletCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.frozen.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "snowflake")
                    .foregroundColor(AppTheme.frozen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Streak Freezes")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if viewModel.isPremium {
                    Text("Unlimited — Premium members never lose a streak to a missed day.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(viewModel.freezesAvailable) remaining · Refills \(formattedRefillDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if viewModel.freezesAvailable == 0 {
                        Button("Go Pro for unlimited freezes") {
                            paywallTrigger = .freezesExhausted
                            showingPaywall = true
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.primary)
                    } else {
                        Text("Premium members get unlimited streak freezes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private var formattedRefillDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewModel.freezeRefillDate)
    }

    private var initials: String {
        if !fullName.isEmpty {
            let parts = fullName.split(separator: " ")
            let firstInitial = parts.first?.prefix(1) ?? ""
            let lastInitial = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
            return "\(firstInitial)\(lastInitial)".uppercased()
        } else if !username.isEmpty {
            return String(username.prefix(2)).uppercased()
        }
        return "?"
    }
    
    private func loadProfile() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            if let profile = try await profileService.fetchProfile(userId: userId) {
                username = profile.username
                fullName = profile.fullName ?? ""
            } else {
                // No profile exists, use email prefix as default username
                if let email = authService.currentUser?.email {
                    username = email.components(separatedBy: "@").first ?? ""
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func saveProfile() {
        guard let userId = authService.currentUser?.id else { return }
        
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // Check if username is available
                let isAvailable = try await profileService.isUsernameAvailable(username, excludingUserId: userId)
                guard isAvailable else {
                    errorMessage = "Username is already taken"
                    isSaving = false
                    return
                }
                
                // Check if profile exists
                if profileService.currentProfile != nil {
                    _ = try await profileService.updateProfile(
                        userId: userId,
                        username: username,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                } else {
                    _ = try await profileService.createProfile(
                        userId: userId,
                        username: username,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                }
                
                // Update local viewModel
                let displayName = fullName.isEmpty ? username : fullName.components(separatedBy: " ").first ?? ""
                viewModel.saveUserName(displayName)
                
                successMessage = "Profile updated!"
                isEditing = false
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    private func cancelEditing() {
        isEditing = false
        errorMessage = nil
        
        // Reset to current profile values
        if let profile = profileService.currentProfile {
            username = profile.username
            fullName = profile.fullName ?? ""
        }
    }
    
    private func signOut() {
        Task {
            try? await authService.signOut()
            // No need to dismiss — Track21App automatically switches
            // to LoginView when currentUser becomes nil
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                viewModel.clearData()
                try await authService.deleteAccount()
                // No need to dismiss — Track21App automatically switches
                // to LoginView when currentUser becomes nil
            } catch {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                isDeletingAccount = false
            }
        }
    }
}

// MARK: - Profile Text Field

struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
            } else {
                Text(text.isEmpty ? "Not set" : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(8)
            }
        }
    }
}
