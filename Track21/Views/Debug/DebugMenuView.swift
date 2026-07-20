//
//  DebugMenuView.swift
//  Track21
//
//  Manual testing controls — freeze wallet, premium flag, buddy onboarding,
//  a full local reset. Compiled entirely out of release builds via #if
//  DEBUG, so none of this can ever ship or be reachable in production.
//

#if DEBUG
import SwiftUI
internal import Auth

struct DebugMenuView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService

    @Bindable private var freezeService = StreakFreezeService.shared
    @State private var buddyService = BuddyService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetConfirm = false
    @State private var syncMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Premium") {
                    Toggle("Premium Enabled", isOn: $freezeService.isPremium)
                }

                Section("Streak Freeze Wallet") {
                    HStack {
                        Text("Freezes Available")
                        Spacer()
                        Text("\(freezeService.freezesAvailable)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Refill Date")
                        Spacer()
                        Text(freezeService.refillDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("−1 Freeze") {
                            freezeService.debugAdjustFreezes(by: -1)
                        }
                        Button("+1 Freeze") {
                            freezeService.debugAdjustFreezes(by: 1)
                        }
                        Spacer()
                        Button("Reset to 2") {
                            freezeService.debugResetWallet()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Section("Buddy") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(buddyService.buddyName ?? "Not named yet")
                            .foregroundColor(.secondary)
                    }
                    Button("Reset Buddy Onboarding") {
                        buddyService.clearData()
                    }
                }

                Section("App Intro") {
                    Button("Reset Intro Carousel") {
                        UserDefaults.standard.set(false, forKey: "Track21HasSeenOnboarding")
                    }
                }

                if let userId = authService.currentUser?.id {
                    Section("Sync") {
                        Button("Force Sync Now") {
                            Task {
                                await viewModel.syncWithCloud(userId: userId)
                                syncMessage = "Synced at \(Date().formatted(date: .omitted, time: .standard))"
                            }
                        }
                        if let syncMessage {
                            Text(syncMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Danger Zone") {
                    Button("Reset All Local Data", role: .destructive) {
                        showingResetConfirm = true
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset all local data?", isPresented: $showingResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.clearData()
                    buddyService.clearData()
                    freezeService.debugResetWallet()
                    UserDefaults.standard.set(false, forKey: "Track21HasSeenOnboarding")
                }
            } message: {
                Text("Clears all habits, your buddy's name, the intro carousel, and resets the freeze wallet. This can't be undone.")
            }
        }
    }
}
#endif
