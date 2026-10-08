//
//  ProfileView.swift
//  Track21
//
//  Created by Hrishav Sunar on 5/2/2026.
//

import SwiftUI
import StoreKit
internal import Auth

struct ProfileView: View {
    @Bindable var authService: AuthService
    @Bindable var profileService: ProfileService
    @Bindable var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String = ""
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingPaywall = false
    @State private var paywallTrigger: PaywallView.Trigger = .general
    @State private var premiumService = PremiumService.shared
    @State private var showingManageSubscriptions = false
    @State private var buddyService = BuddyService.shared
    @State private var showingClearChatAlert = false
    @State private var showingRenameBuddy = false
    @State private var showingArchive = false
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    var body: some View {
        NavigationView {
            List {
                profileSection
                achievementsSection
                premiumSection
                freezeSection
                buddySection
                aboutSection
                signOutSection
                deleteAccountSection
            }
            .listStyle(.insetGrouped)
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
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete Account", role: .destructive) {
                    guard deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete" else {
                        return
                    }
                    deleteConfirmationText = ""
                    deleteAccount()
                }
                .disabled(deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "delete")
            } message: {
                Text("This permanently deletes your account and all your data. Type DELETE to continue.")
            }
            .alert("Clear Chat History", isPresented: $showingClearChatAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    buddyService.clearChatHistory()
                }
            } message: {
                Text("This will permanently delete all your conversations with \(buddyService.buddyName ?? "your buddy"). This action cannot be undone.")
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView(viewModel: viewModel, authService: authService)
            }
            #endif
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: paywallTrigger)
            }
            .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
            .sheet(isPresented: $showingArchive) {
                HabitArchiveView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingRenameBuddy) {
                BuddyRenameSheet(currentName: buddyService.buddyName ?? BuddyNameLogic.defaultName) { newName in
                    buddyService.renameBuddy(to: newName)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var profileSection: some View {
        Section {
            NavigationLink {
                EditProfileView(
                    authService: authService,
                    profileService: profileService,
                    viewModel: viewModel,
                    fullName: $fullName,
                    successMessage: $successMessage
                )
            } label: {
                HStack(spacing: 16) {
                    avatarView

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fullName.isEmpty ? emailPrefix : fullName)
                            .font(.headline)
                        if let email = authService.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .accessibilityLabel("Edit Profile")

            if let success = successMessage {
                Text(success)
                    .font(.caption)
                    .foregroundColor(AppTheme.primary)
            }
        }
    }

    @ViewBuilder
    private var achievementsSection: some View {
        Section {
            NavigationLink {
                AchievementsView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    iconBadge("trophy.fill", color: .yellow)
                    Text("Achievements")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(achievementSummary.unlocked) of \(achievementSummary.total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Achievements")

            Button {
                showingArchive = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("archivebox.fill", color: AppTheme.primary)
                    Text("Trophy Case")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.archivedHabits.isEmpty
                          ? "Empty"
                          : "\(viewModel.archivedHabits.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .accessibilityLabel("Trophy Case")
        }
    }

    @ViewBuilder
    private var premiumSection: some View {
        Section {
            if viewModel.isPremium {
                HStack(spacing: 12) {
                    iconBadge("crown.fill", color: AppTheme.primary)
                    Text("Track21 Pro")
                    Spacer()
                    Text("Active")
                        .foregroundColor(.secondary)
                }

                // Lifetime owners have no subscription to manage.
                if premiumService.hasActiveSubscription {
                    Button {
                        showingManageSubscriptions = true
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge("creditcard.fill", color: .gray)
                            Text("Manage Subscription")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                    .accessibilityHint("Opens your App Store subscription settings")
                }
            } else {
                Button {
                    paywallTrigger = .general
                    showingPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        iconBadge("crown.fill", color: AppTheme.primary)
                        Text("Go Pro")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
                .accessibilityLabel("Go Pro")
                .accessibilityHint("Opens the Track21 Pro upgrade screen")
            }
        }
    }

    @ViewBuilder
    private var freezeSection: some View {
        Section {
            HStack(spacing: 12) {
                iconBadge("snowflake", color: AppTheme.frozen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak Freezes")
                    if viewModel.isPremium {
                        Text("Unlimited")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(viewModel.freezesAvailable) remaining · Refills \(formattedRefillDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if !viewModel.isPremium && viewModel.freezesAvailable == 0 {
                Button("Go Pro for unlimited freezes") {
                    paywallTrigger = .freezesExhausted
                    showingPaywall = true
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var buddySection: some View {
        Section {
            Button {
                showingRenameBuddy = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("person.crop.circle.fill", color: AppTheme.primary)
                    Text("Buddy name")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(buddyService.buddyName ?? BuddyNameLogic.defaultName)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .accessibilityLabel("Buddy name, \(buddyService.buddyName ?? BuddyNameLogic.defaultName)")
            .accessibilityHint("Rename your buddy")

            Button(role: .destructive) {
                showingClearChatAlert = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("trash.fill", color: .red)
                    Text("Clear Chat History")
                        .foregroundColor(.primary)
                    Spacer()
                    if buddyService.conversations.count > 0 {
                        Text("\(buddyService.conversations.count) conversation\(buddyService.conversations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(buddyService.conversations.isEmpty)
        } header: {
            Text("AI Buddy")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            #if DEBUG
            Button {
                showingDebugMenu = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("hammer.fill", color: .gray)
                    Text("Debug Menu")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            #endif

            Link(destination: URL(string: "https://hrishav200.github.io/Track21/privacy/")!) {
                HStack(spacing: 12) {
                    iconBadge("hand.raised.fill", color: .blue)
                    Text("Privacy Policy")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
            .accessibilityLabel("Sign Out")
        }
    }

    @ViewBuilder
    private var deleteAccountSection: some View {
        if !authService.isGuest {
            Section {
                Button(role: .destructive) {
                    deleteConfirmationText = ""
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeletingAccount {
                            ProgressView()
                        } else {
                            Text("Delete Account")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeletingAccount)
                .accessibilityLabel("Delete Account")
            } footer: {
                Text("Permanently removes your account and all synced data. This cannot be undone.")
            }
        }
    }

    // MARK: - Shared pieces

    private func iconBadge(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 29, height: 29)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var avatarView: some View {
        Circle()
            .fill(AppTheme.primary.opacity(0.2))
            .frame(width: 56, height: 56)
            .overlay(
                Text(initials)
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppTheme.primary)
            )
            .accessibilityLabel("Profile avatar: \(initials)")
    }

    private var achievementSummary: (unlocked: Int, total: Int) {
        let all = AchievementService.shared.refresh(habits: viewModel.habits).all
        return (all.filter(\.isUnlocked).count, all.count)
    }

    private var formattedRefillDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewModel.freezeRefillDate)
    }

    private var emailPrefix: String {
        authService.currentUser?.email?.components(separatedBy: "@").first ?? "?"
    }

    private var initials: String {
        if !fullName.isEmpty {
            let parts = fullName.split(separator: " ")
            let firstInitial = parts.first?.prefix(1) ?? ""
            let lastInitial = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
            return "\(firstInitial)\(lastInitial)".uppercased()
        } else if !emailPrefix.isEmpty {
            return String(emailPrefix.prefix(2)).uppercased()
        }
        return "?"
    }

    private func loadProfile() async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            if let profile = try await profileService.fetchProfile(userId: userId) {
                fullName = profile.fullName ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
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
