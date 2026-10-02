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
    @State private var showingTrophyPreview = false
    @State private var previewingCompleteArchive = false
    @State private var seedMessage: String?

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
                                    do {
                                        _ = try await premiumService.purchase(product)
                                    } catch {
                                        // purchaseError already set inside PremiumService
                                    }
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

                Section("Trophy Case") {
                    Button("Seed Fully Complete Archive") {
                        seedFullyCompleteArchive()
                    }
                    Text("Upserts \"Debug Complete Cycle\" (Perfect 21, full habit-color strip) into Trophy Case. Does not modify Protein/Water/Creatine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Preview Complete Row (no save)") {
                        previewingCompleteArchive = true
                    }
                    Text("Shows the filled Trophy Case row/detail with sample data only — never writes habits.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if viewModel.habits.contains(where: { $0.id == Self.debugCompleteId || $0.name == Self.debugCompleteName }) {
                        Button("Remove Debug Archive Habit", role: .destructive) {
                            viewModel.debugRemoveHabit(named: Self.debugCompleteName)
                            seedMessage = "Removed Debug Complete Cycle"
                        }
                    }
                    if let seedMessage {
                        Text(seedMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            .sheet(isPresented: $showingTrophyPreview) {
                HabitArchiveView(viewModel: viewModel)
                    .onAppear {
                        // If a mid-flight sync still raced us, re-upsert once the
                        // Trophy Case sheet is visible so the row is never missing.
                        ensureDebugCompleteSeeded()
                    }
            }
            .sheet(isPresented: $previewingCompleteArchive) {
                // Ephemeral name → random id, so Delete in this sheet can't
                // clobber the saved "Debug Complete Cycle" seed.
                ArchiveHabitDetailView(
                    habit: Self.makeFullyCompleteArchiveHabit(
                        name: "Preview Complete Cycle",
                        goal: "Ephemeral preview — not saved"
                    ),
                    viewModel: viewModel
                )
            }
        }
    }

    private static let debugCompleteName = "Debug Complete Cycle"
    /// Stable id so re-tapping seed replaces the same row instead of stacking.
    private static let debugCompleteId = UUID(uuidString: "00000000-0021-4000-8000-000000000021")!

    /// Upserts a finished perfect 21-day cycle so Trophy Case shows a full
    /// habit-color strip and matching day count — without touching real habits.
    private func seedFullyCompleteArchive() {
        ensureDebugCompleteSeeded()
        let accounted = viewModel.habits
            .first(where: { $0.id == Self.debugCompleteId || $0.name == Self.debugCompleteName })?
            .cycleDaysAccounted ?? -1
        seedMessage = "Seeded Debug Complete Cycle · \(accounted)/21 — opening Trophy Case"
        showingTrophyPreview = true
    }

    private func ensureDebugCompleteSeeded() {
        let habit = Self.makeFullyCompleteArchiveHabit()
        // Attach the signed-in user so a later sync uploads instead of orphaning.
        habit.userId = authService.currentUser?.id
        habit.syncStatus = .pending
        viewModel.debugReplaceOrInsertHabit(habit)
        // Mark victory as already shown so seeding doesn't pop HabitVictoryView.
        _ = HabitVictoryService.shared.checkForNewVictory(habit)
        print("[Track21][debug] archivedHabits=\(viewModel.archivedHabits.map(\.name))")
    }

    /// A fully-completed 21-day habit purely for previewing the victory
    /// screen from the debug menu — never saved, never touches real data.
    private static var sampleVictoryHabit: Habit {
        makeFullyCompleteArchiveHabit(
            name: "Drink Water",
            goal: "8 glasses",
            color: "5DD167"
        )
    }

    /// Saved debug habit for Trophy Case: cycle window closed (started 20
    /// days ago) with every day completed — Perfect 21 / full color strip.
    private static func makeFullyCompleteArchiveHabit(
        name: String = debugCompleteName,
        goal: String = "Debug preview — safe to delete",
        color: String = "F5A623"
    ) -> Habit {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -20, to: Date()) ?? Date()
        )
        let habit = Habit(
            id: name == debugCompleteName ? debugCompleteId : UUID(),
            name: name,
            goal: goal,
            color: color,
            startDate: startDate
        )
        habit.completedDates = (0...20).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startDate).map { calendar.startOfDay(for: $0) }
        }
        habit.frozenDates = []
        return habit
    }
}
#endif
