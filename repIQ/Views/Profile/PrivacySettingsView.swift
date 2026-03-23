import SwiftUI

struct PrivacySettingsView: View {
    @State private var viewModel = SocialViewModel()
    @State private var selectedPrivacy: PrivacyLevel = .friendsOnly
    @State private var isSaving = false
    @State private var saveSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.lg) {
                        Text("Workout Visibility")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Text("Control who can see your workout activity, stats, and progress.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        ForEach(PrivacyLevel.allCases, id: \.self) { level in
                            privacyOption(level)
                        }
                    }
                }

                // Save button
                Button {
                    Task { await savePrivacy() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(RQColors.background)
                        } else if saveSuccess {
                            Image(systemName: "checkmark")
                            Text("Saved")
                        } else {
                            Text("Save")
                        }
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent)
                    .cornerRadius(RQRadius.medium)
                }
                .disabled(isSaving)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadSocialData()
            if let profile = viewModel.socialProfile {
                selectedPrivacy = profile.privacyLevel
            }
        }
    }

    private func privacyOption(_ level: PrivacyLevel) -> some View {
        let isSelected = selectedPrivacy == level

        return Button {
            selectedPrivacy = level
            saveSuccess = false
        } label: {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: privacyIcon(level))
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(level.displayName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    Text(privacyDescription(level))
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
            }
            .padding(.vertical, RQSpacing.xs)
        }
    }

    private func privacyIcon(_ level: PrivacyLevel) -> String {
        switch level {
        case .public_: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .private_: return "lock.fill"
        }
    }

    private func privacyDescription(_ level: PrivacyLevel) -> String {
        switch level {
        case .public_: return "Anyone can see your workouts"
        case .friendsOnly: return "Only friends see your workouts"
        case .private_: return "Your workouts are hidden"
        }
    }

    private func savePrivacy() async {
        isSaving = true
        saveSuccess = false
        await viewModel.updateProfile(
            username: viewModel.socialProfile?.username,
            bio: viewModel.socialProfile?.bio,
            privacyLevel: selectedPrivacy
        )
        isSaving = false
        saveSuccess = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveSuccess = false
        }
    }
}
