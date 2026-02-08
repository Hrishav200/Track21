//
//  PasswordResetView.swift
//  Track21
//
//  Created by GOLU on 8/2/2026.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Password Reset View
struct PasswordResetView: View {
    @StateObject private var viewModel = PasswordResetViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Reset Your Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your new password below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Password Fields
                VStack(spacing: 16) {
                    SecureField("New Password", text: $viewModel.password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    // Password strength indicator
                    if !viewModel.password.isEmpty {
                        PasswordStrengthView(password: viewModel.password)
                    }
                }
                .padding(.horizontal)
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Reset Button
                Button(action: {
                    Task {
                        await viewModel.resetPassword()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Reset Password")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully!")
            }
        }
    }
}

// MARK: - View Model
@MainActor
class PasswordResetViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    private let supabase = SupabaseConfig.client
    
    var isFormValid: Bool {
        !password.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    func resetPassword() async {
        guard isFormValid else {
            errorMessage = "Please check your password and try again"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )
            
            isLoading = false
            showSuccess = true
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Password Strength Indicator
struct PasswordStrengthView: View {
    let password: String
    
    var strength: PasswordStrength {
        if password.count < 8 { return .weak }
        if password.count < 12 { return .medium }
        
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        
        let criteriaCount = [hasUppercase, hasLowercase, hasNumber, hasSpecial].filter { $0 }.count
        
        if criteriaCount >= 3 { return .strong }
        return .medium
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(index < strength.bars ? strength.color : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            
            Text(strength.text)
                .font(.caption)
                .foregroundColor(strength.color)
        }
        .padding(.horizontal)
    }
}

enum PasswordStrength {
    case weak, medium, strong
    
    var bars: Int {
        switch self {
        case .weak: return 1
        case .medium: return 2
        case .strong: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
    
    var text: String {
        switch self {
        case .weak: return "Weak password"
        case .medium: return "Medium strength"
        case .strong: return "Strong password"
        }
    }
}

// MARK: - Custom Text Field Style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
