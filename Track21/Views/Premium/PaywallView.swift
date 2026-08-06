//
//  PaywallView.swift
//  Track21
//
//  "Go Pro" sheet — triggered from the Profile upgrade card, running out of
//  streak freezes, hitting the daily Buddy chat cap, or tapping a locked
//  stats cell. All roads lead here rather than each caller building its own.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    /// Which trigger opened the paywall — purely for the headline copy, so
    /// the pitch feels relevant to whatever the user just bumped into.
    enum Trigger {
        case general, freezesExhausted, chatCapped, lockedStats

        var headline: String {
            switch self {
            case .general: return "Track21 Pro"
            case .freezesExhausted: return "Out of streak freezes"
            case .chatCapped: return "You've hit today's chat limit"
            case .lockedStats: return "Unlock your full history"
            }
        }
    }

    var trigger: Trigger = .general

    @State private var premiumService = PremiumService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseInFlight: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.primary)
                        .padding(.top, 16)

                    VStack(spacing: 8) {
                        Text(trigger.headline)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Go Pro for unlimited freezes, unlimited Buddy chat, and your full stats history.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "snowflake", text: "Unlimited streak freezes")
                        featureRow(icon: "bubble.left.and.bubble.right.fill", text: "Unlimited Buddy chat")
                        featureRow(icon: "chart.bar.fill", text: "Full stats history, every cycle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)

                    if premiumService.products.isEmpty {
                        if premiumService.isLoadingProducts {
                            ProgressView()
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 12) {
                                Text("Pricing isn't available right now.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("Try Again") {
                                    Task { await premiumService.loadProducts() }
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 24)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(premiumService.products) { product in
                                productRow(product)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Button("Restore Purchases") {
                        Task { try? await premiumService.restorePurchases() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if let error = premiumService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await premiumService.loadProducts() }
            .onChange(of: premiumService.hasActiveEntitlement) { _, isActive in
                if isActive { dismiss() }
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func productRow(_ product: Product) -> some View {
        let isAnnual = product.id == PremiumService.annualID

        return Button {
            Task {
                purchaseInFlight = product.id
                _ = try? await premiumService.purchase(product)
                purchaseInFlight = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)
                        if isAnnual {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.primary)
                                .cornerRadius(6)
                        }
                    }
                    if isAnnual {
                        Text("7-day free trial, then billed yearly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if purchaseInFlight == product.id {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                }
            }
            .foregroundColor(.primary)
            .padding()
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isAnnual ? AppTheme.primary : Color.clear, lineWidth: 2)
            )
            .cornerRadius(14)
        }
        .disabled(purchaseInFlight != nil)
    }
}

#Preview {
    PaywallView()
}
