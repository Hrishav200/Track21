//
//  EditProfileView.swift
//  Track21
//
//  Pushed from ProfileView's profile card. Full Name is the only thing
//  editable here:
//  - Email is the Supabase Auth login credential — changing it needs a
//    confirmation-email flow that doesn't exist yet, so it's shown for
//    reference only.
//  - Username no longer has a UI — the app has no @handle-style
//    interactions between users, so it's redundant with email as the
//    unique identifier. It's still a required, unique column in Supabase,
//    so it's auto-derived from the email prefix behind the scenes instead.
//

import SwiftUI
internal import Auth

struct EditProfileView: View {
    @Bindable var authService: AuthService
    @Bindable var profileService: ProfileService
    @Bindable var viewModel: HabitViewModel
    @Binding var fullName: String
    @Binding var successMessage: String?
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Full Name", text: $fullName)
            }

            if let email = authService.currentUser?.email {
                Section {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Email can't be changed here.")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var emailPrefix: String {
        authService.currentUser?.email?.components(separatedBy: "@").first ?? "friend"
    }

    private func save() {
        guard let userId = authService.currentUser?.id else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                if profileService.currentProfile != nil {
                    // username omitted (nil) — leaves the existing,
                    // auto-derived value untouched.
                    _ = try await profileService.updateProfile(
                        userId: userId,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                } else {
                    _ = try await profileService.createProfile(
                        userId: userId,
                        username: try await uniqueDerivedUsername(userId: userId),
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                }

                let displayName = fullName.isEmpty ? emailPrefix : fullName.components(separatedBy: " ").first ?? emailPrefix
                viewModel.saveUserName(displayName)

                successMessage = "Profile updated!"
                isSaving = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    /// The email prefix, unless another account already claimed it as
    /// their (equally invisible) username — a short random suffix breaks
    /// the tie so account creation never fails over this.
    private func uniqueDerivedUsername(userId: UUID) async throws -> String {
        let base = emailPrefix
        if try await profileService.isUsernameAvailable(base, excludingUserId: userId) {
            return base
        }
        return "\(base)\(Int.random(in: 1000...9999))"
    }
}
