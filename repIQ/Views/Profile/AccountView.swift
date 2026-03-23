import SwiftUI
import Supabase

struct AccountView: View {
    let profile: Profile?
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var showPasswordResetAlert = false
    @State private var passwordResetSent = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Email (read-only)
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Email")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        HStack {
                            Image(systemName: "envelope")
                                .font(.system(size: 14))
                                .foregroundColor(RQColors.textTertiary)

                            Text(profile?.email ?? "No email")
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                        }
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, RQSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RQColors.surfaceTertiary.opacity(0.5))
                        .cornerRadius(RQRadius.medium)

                        Text("Your email is used for sign-in and cannot be changed here.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                // Username
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Username")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        TextField("Choose a username", text: $username)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal, RQSpacing.md)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)

                        Button {
                            Task { await saveUsername() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(RQColors.background)
                                } else if saveSuccess {
                                    Image(systemName: "checkmark")
                                    Text("Saved")
                                } else {
                                    Text("Save Username")
                                }
                            }
                            .font(RQTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.accent)
                            .cornerRadius(RQRadius.medium)
                        }
                        .disabled(isSaving)
                    }
                }

                // Change Password
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Password")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Text("A password reset link will be sent to your email address.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        Button {
                            showPasswordResetAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 14))
                                Text("Change Password")
                                    .font(RQTypography.body)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(RQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                        }

                        if passwordResetSent {
                            HStack(spacing: RQSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(RQColors.success)
                                Text("Reset link sent to your email")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.success)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.error)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(RQColors.background)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            username = profile?.username ?? ""
        }
        .alert("Change Password", isPresented: $showPasswordResetAlert) {
            Button("Send Reset Link") {
                Task { await sendPasswordReset() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll send a password reset link to \(profile?.email ?? "your email").")
        }
    }

    private func saveUsername() async {
        isSaving = true
        saveSuccess = false
        errorMessage = nil
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            try await supabase.from("profiles")
                .update(["username": username.isEmpty ? nil : username] as [String: String?])
                .eq("id", value: userId.uuidString)
                .execute()
            saveSuccess = true
            // Reset success after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                saveSuccess = false
            }
        } catch {
            errorMessage = "Failed to save username."
        }
        isSaving = false
    }

    private func sendPasswordReset() async {
        errorMessage = nil
        guard let email = profile?.email else {
            errorMessage = "No email address found."
            return
        }
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            passwordResetSent = true
        } catch {
            errorMessage = "Failed to send reset email: \(error.localizedDescription)"
        }
    }
}
