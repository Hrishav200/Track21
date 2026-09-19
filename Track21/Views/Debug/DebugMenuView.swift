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
import StoreKit
internal import Auth

struct DebugMenuView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService

    @Bindable private var freezeService = StreakFreezeService.shared
    @Bindable private var premiumService = PremiumService.shared
    @State private var buddyService = BuddyService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetConfirm = false
    @State private var syncMessage: String?
    @State private var purchaseInFlight: String?
    @State private var previewingVictory = false

    var body: some View {
        NavigationView {
            Form {
                Section("Premium") {
                    Toggle("Force Pro (ignore entitlement)", isOn: $premiumService.debugOverride)
                        .disabled(premiumService.debugForceFree)
                    Toggle("Force Free (ignore entitlement)", isOn: $premiumService.debugForceFree)
                        .disabled(premiumService.debugOverride)
                    HStack {
                        Text("Real Entitlement")
                        Spacer()
                        Text(premiumService.hasActiveEntitlement ? "Active" : "None")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Effective Status")
                        Spacer()
                        Text(premiumService.isPremium ? "Pro" : "Free")
                            .foregroundColor(premiumService.isPremium ? .green : .secondary)
                            .fontWeight(.medium)
                    }
                }

                Section("Track21 Pro (StoreKit)") {
                    if premiumService.products.isEmpty {
                        Text(premiumService.isLoadingProducts ? "Loading products…" : "No products loaded.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(premiumService.products) { product in
                            Button {
                                Task {
                                    purchaseInFlight = product.id
                                    _ = try? await premiumService.purchase(product)
                                    purchaseInFlight = nil
                                }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    if purchaseInFlight == product.id {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .disabled(purchaseInFlight != nil)
                        }
                    }
                    Button("Restore Purchases") {
                        Task { try? await premiumService.restorePurchases() }
                    }
                    if let error = premiumService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
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

                Section("Habit Victory Screen") {
                    Button("Preview Victory Screen") {
                        previewingVictory = true
                    }
                    Text("Shows the full-screen celebration with sample data — doesn't affect real habits.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    premiumService.debugOverride = false
                    UserDefaults.standard.set(false, forKey: "Track21HasSeenOnboarding")
                }
            } message: {
                Text("Clears all habits, your buddy's name, the intro carousel, and resets the freeze wallet. This can't be undone.")
            }
            .fullScreenCover(isPresented: $previewingVictory) {
                HabitVictoryView(habit: Self.sampleVictoryHabit) {
                    previewingVictory = false
                }
            }
        }
    }

    /// A fully-completed 21-day habit purely for previewing the victory
    /// screen from the debug menu — never saved, never touches real data.
    private static var sampleVictoryHabit: Habit {
        let habit = Habit(
            name: "Drink Water",
            goal: "8 glasses",
            color: "5DD167",
            startDate: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date()
        )
        for offset in 0...20 {
            if let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                habit.completedDates.append(Calendar.current.startOfDay(for: day))
            }
        }
        return habit
    }
}
#endif
