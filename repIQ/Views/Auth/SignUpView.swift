import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: RQSpacing.xl) {
            // Display Name
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("Name")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                RQTextField(
                    placeholder: "Your name",
                    text: $viewModel.displayName,
                    autocapitalization: .words
                )
            }

            // Email
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("Email")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                RQTextField(
                    placeholder: "your@email.com",
                    text: $viewModel.email,
                    keyboardType: .emailAddress,
                    autocapitalization: .never
                )
            }

            // Password
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("Password")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                RQTextField(
                    placeholder: "Minimum 6 characters",
                    text: $viewModel.password,
                    isSecure: true
                )
            }

            // Success
            if let success = viewModel.successMessage {
                Text(success)
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.success)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, RQSpacing.sm)
                    .background(RQColors.success.opacity(0.1))
                    .cornerRadius(RQRadius.small)
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.error)
                    .multilineTextAlignment(.center)
            }

            // Sign Up Button
            RQButton(
                title: "Create Account",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isFormValid
            ) {
                Task { await viewModel.signUp() }
            }

            // Divider
            HStack {
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(RQColors.surfaceTertiary)
                Text("or")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(RQColors.surfaceTertiary)
            }

            // Apple Sign In
            SignInWithAppleButton(.signUp) { request in
                viewModel.handleAppleSignInRequest(request)
            } onCompletion: { result in
                Task { await viewModel.handleAppleSignInCompletion(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(RQRadius.medium)

            // Google Sign In
            GoogleSignInButton {
                Task { await viewModel.signInWithGoogle() }
            }

            // Switch to Sign In
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSignUp = false
                    viewModel.errorMessage = nil
                }
            } label: {
                HStack(spacing: RQSpacing.xs) {
                    Text("Already have an account?")
                        .foregroundColor(RQColors.textSecondary)
                    Text("Sign In")
                        .foregroundColor(RQColors.accent)
                        .fontWeight(.semibold)
                }
                .font(RQTypography.subheadline)
            }
        }
    }
}
