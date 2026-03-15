import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: RQSpacing.xl) {
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
                    placeholder: "Password",
                    text: $viewModel.password,
                    isSecure: true
                )
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.error)
                    .multilineTextAlignment(.center)
            }

            // Sign In Button
            RQButton(
                title: "Sign In",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isFormValid
            ) {
                Task { await viewModel.signIn() }
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
            SignInWithAppleButton(.signIn) { request in
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

            // Switch to Sign Up
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSignUp = true
                    viewModel.errorMessage = nil
                }
            } label: {
                HStack(spacing: RQSpacing.xs) {
                    Text("Don't have an account?")
                        .foregroundColor(RQColors.textSecondary)
                    Text("Sign Up")
                        .foregroundColor(RQColors.accent)
                        .fontWeight(.semibold)
                }
                .font(RQTypography.subheadline)
            }
        }
    }
}
