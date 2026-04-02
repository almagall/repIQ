import SwiftUI

/// Social profile editor — username, bio, privacy settings.
struct SocialProfileView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var privacyLevel: PrivacyLevel = .friendsOnly
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Avatar & Display Name
                profileHeader

                // Username
                editField(title: "USERNAME", value: $username, placeholder: "Choose a username")

                // Bio
                bioField

                // Privacy
                privacyPicker

                // Stats overview
                statsSection

                // Save button
                Button {
                    isSaving = true
                    Task {
                        await viewModel.updateProfile(
                            username: username.isEmpty ? nil : username,
                            bio: bio.isEmpty ? nil : bio,
                            privacyLevel: privacyLevel
                        )
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(RQColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.lg)
                            .background(RQColors.accent)
                            .cornerRadius(RQRadius.medium)
                    } else {
                        Text("Save Profile")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.lg)
                            .background(RQColors.accent)
                            .cornerRadius(RQRadius.medium)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Social Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            username = viewModel.socialProfile?.username ?? ""
            bio = viewModel.socialProfile?.bio ?? ""
            privacyLevel = viewModel.socialProfile?.privacyLevel ?? .friendsOnly
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: RQSpacing.md) {
            Circle()
                .fill(RQColors.accent.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String((viewModel.socialProfile?.username ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(RQColors.accent)
                )

            if let username = viewModel.socialProfile?.username {
                Text(username)
                    .font(RQTypography.title2)
                    .foregroundColor(RQColors.textPrimary)
            }

            // League badge
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: viewModel.currentTier.icon)
                    .font(.system(size: 14))
                Text(viewModel.currentTier.displayName)
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(tierColor(viewModel.currentTier))
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.xs)
            .background(tierColor(viewModel.currentTier).opacity(0.15))
            .cornerRadius(RQRadius.large)
        }
    }

    // MARK: - Edit Fields

    private func editField(title: String, value: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text(title)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .tracking(1.5)

            TextField(placeholder, text: value)
                .font(RQTypography.body)
                .foregroundColor(RQColors.textPrimary)
                .autocapitalization(.none)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.md)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.medium)
        }
    }

    private var bioField: some View {
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
    }

    // MARK: - Privacy Picker

    private var privacyPicker: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("PRIVACY")
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .tracking(1.5)

            ForEach([PrivacyLevel.public_, .friendsOnly, .private_], id: \.rawValue) { level in
                Button {
                    privacyLevel = level
                } label: {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: privacyIcon(level))
                            .font(.system(size: 14))
                            .foregroundColor(privacyLevel == level ? RQColors.accent : RQColors.textTertiary)
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

                        if privacyLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(RQColors.accent)
                        }
                    }
                    .padding(RQSpacing.md)
                    .background(privacyLevel == level ? RQColors.accent.opacity(0.1) : RQColors.surfaceTertiary)
                    .cornerRadius(RQRadius.medium)
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("SOCIAL STATS")
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .tracking(1.5)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: RQSpacing.md) {
                statCard(icon: "flame.fill", value: "\(viewModel.currentStreak)", label: "Day Streak", color: RQColors.warning)
                statCard(icon: "person.2.fill", value: "\(viewModel.friends.count)", label: "Friends", color: RQColors.info)
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: RQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(RQTypography.numbers)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Helpers

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

    private func tierColor(_ tier: LeagueTier) -> Color {
        switch tier {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C0C0C0")
        case .gold: return RQColors.warning
        case .platinum: return Color(hex: "E5E4E2")
        case .diamond: return RQColors.info
        case .elite: return RQColors.accent
        }
    }
}
