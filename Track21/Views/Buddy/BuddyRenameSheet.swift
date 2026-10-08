//
//  BuddyRenameSheet.swift
//  Track21
//
//  Small sheet for renaming the accountability buddy after onboarding.
//  Opened from Profile → AI Buddy → Buddy name, and from the Buddy chat title.
//

import SwiftUI

struct BuddyRenameSheet: View {
    let currentName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var fieldFocused: Bool

    init(currentName: String, onSave: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    private var validation: BuddyNameLogic.Validation { BuddyNameLogic.validate(name) }
    private var canSave: Bool { BuddyNameLogic.isChange(name, from: currentName) }
    private var characterCount: Int { BuddyNameLogic.sanitize(name).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Max, Coach, Rae", text: $name)
                        .focused($fieldFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityLabel("Buddy name")
                        .accessibilityIdentifier("buddyRenameField")
                } header: {
                    Text("Buddy\u{2019}s name")
                } footer: {
                    if let error = BuddyNameLogic.errorMessage(for: validation) {
                        Text(error).foregroundColor(.red)
                    } else {
                        Text("\(characterCount)/\(BuddyNameLogic.maxLength). Shows in chat, greetings and nudges.")
                    }
                }
            }
            .navigationTitle("Rename Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("buddyRenameSave")
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard canSave, case .valid(let newName) = validation else { return }
        onSave(newName)
        dismiss()
    }
}

#Preview {
    BuddyRenameSheet(currentName: "Max", onSave: { _ in })
}
