//
//  BuddyNamingView.swift
//  Track21
//
//  One-time onboarding screen: names the user's accountability buddy before
//  they land in the main app. Shown as a fullScreenCover from ContentView
//  whenever BuddyService has no saved name yet.
//

import SwiftUI

struct BuddyNamingView: View {
    let onContinue: (String) -> Void

    @State private var name = ""
    @FocusState private var fieldFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.2.arms.open")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.primary)

            VStack(spacing: 8) {
                Text("Name your accountability buddy")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("They'll cheer you on, check in when a streak's at risk, and chat whenever you need a nudge.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            TextField("e.g. Max, Coach, Rae", text: $name)
                .textFieldStyle(.plain)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(14)
                .padding(.horizontal, 40)
                .focused($fieldFocused)
                .accessibilityLabel("Buddy name")
                .submitLabel(.done)
                .onSubmit(continueTapped)

            Spacer()

            VStack(spacing: 12) {
                Button(action: continueTapped) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(trimmedName.isEmpty ? AppTheme.primary.opacity(0.4) : AppTheme.primary)
                        .cornerRadius(14)
                }
                .disabled(trimmedName.isEmpty)
                .accessibilityLabel("Continue")
                .accessibilityIdentifier("buddyNamingContinue")
                .padding(.horizontal, 24)

                Button("Skip — call them Buddy") {
                    onContinue("Buddy")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .onAppear { fieldFocused = true }
    }

    private func continueTapped() {
        guard !trimmedName.isEmpty else { return }
        onContinue(trimmedName)
    }
}

#Preview {
    BuddyNamingView(onContinue: { _ in })
}
