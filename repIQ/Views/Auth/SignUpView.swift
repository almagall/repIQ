import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        if viewModel.successMessage != nil {
            emailConfirmationView
        } else {
            signUpForm
        }
    }

    // MARK: - Sign Up Form

    private var signUpForm: some View {
        VStack(spacing: RQSpacing.xl) {
            // Username
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("Username")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                RQTextField(
                    placeholder: "letters, numbers, underscores",
                    text: $viewModel.username,
                    autocapitalization: .never
                )
                if !viewModel.username.isEmpty && !viewModel.isUsernameValid {
                    Text("3–20 characters · letters, numbers, and underscores only")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
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

    // MARK: - Email Confirmation Screen

    private var emailConfirmationView: some View {
        VStack(spacing: RQSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(RQColors.accent.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 40))
                    .foregroundColor(RQColors.accent)
            }

            // Copy
            VStack(spacing: RQSpacing.sm) {
                Text("Check your inbox")
                    .font(RQTypography.title2)
                    .foregroundColor(RQColors.textPrimary)

                Text("We sent a confirmation link to")
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)

                Text(viewModel.email)
                    .font(RQTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.accent)

                Text("Tap the link in the email to activate your account. Once confirmed, come back here and sign in.")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, RQSpacing.xs)

                Text("The confirmation page may show a blank screen — that's normal. Just return to the app.")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, RQSpacing.xxs)
            }

            Spacer()

            // Back to Sign In
            RQButton(title: "Go to Sign In") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.successMessage = nil
                    viewModel.isSignUp = false
                    viewModel.password = ""
                }
            }

            // Didn't receive it note
            Text("Didn't get it? Check your spam folder.")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}
