import SwiftUI

/// Quick setup sheet for first-time social profile configuration.
struct SocialSetupSheet: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var bio = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    // Hero
                    VStack(spacing: RQSpacing.md) {
                        Circle()
                            .fill(RQColors.accent.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(RQColors.accent)
                            )

                        Text("Set Up Your Social Profile")
                            .font(RQTypography.title2)
                            .foregroundColor(RQColors.textPrimary)

                        Text("Choose a username so friends can find you and see your progress.")
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, RQSpacing.lg)

                    // Username
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("USERNAME")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textTertiary)
                            .tracking(1.5)

                        TextField("Choose a username", text: $username)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal, RQSpacing.md)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                    }

                    // Bio
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        HStack {
                            Text("BIO")
                                .font(RQTypography.label)
                                .foregroundColor(RQColors.textTertiary)
                                .tracking(1.5)

                            Spacer()

                            Text("\(bio.count)/200")
                                .font(RQTypography.label)
                                .foregroundColor(bio.count > 200 ? RQColors.error : RQColors.textTertiary)
                        }

                        TextField("Tell others about yourself", text: $bio, axis: .vertical)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .lineLimit(3...5)
                            .padding(.horizontal, RQSpacing.md)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                    }

                    // Save
                    Button {
                        isSaving = true
                        Task {
                            await viewModel.updateProfile(
                                username: username.isEmpty ? nil : username,
                                bio: bio.isEmpty ? nil : bio,
                                privacyLevel: viewModel.socialProfile?.privacyLevel ?? .friendsOnly
                            )
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(RQColors.background)
                            } else {
                                Text("Save & Continue")
                                    .font(RQTypography.headline)
                            }
                        }
                        .foregroundColor(RQColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.lg)
                        .background(username.isEmpty ? RQColors.accent.opacity(0.4) : RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                    }
                    .disabled(username.isEmpty || isSaving)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(RQColors.background)
            .navigationTitle("Social Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }
}
