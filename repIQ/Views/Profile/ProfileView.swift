import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showWeightUnitPicker = false
    @State private var showRestTimerPicker = false
    @State private var username = ""
    @State private var bio = ""
    @State private var isSavingSocial = false

    private let restTimerOptions = [60, 90, 120, 150, 180, 210, 240]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Profile Header
                    RQCard {
                        HStack(spacing: RQSpacing.lg) {
                            Circle()
                                .fill(RQColors.accent.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(RQColors.accent)
                                )

                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text(viewModel.profile?.displayName ?? "Athlete")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                Text(viewModel.profile?.email ?? "")
                                    .font(RQTypography.subheadline)
                                    .foregroundColor(RQColors.textSecondary)
                            }
                            Spacer()
                        }
                    }

                    // Social Identity Section
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.lg) {
                            Text("Social Identity")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

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
                                isSavingSocial = true
                                Task {
                                    await viewModel.updateUsernameAndBio(
                                        username: username.isEmpty ? nil : username,
                                        bio: bio.isEmpty ? nil : bio
                                    )
                                    isSavingSocial = false
                                }
                            } label: {
                                HStack {
                                    if isSavingSocial {
                                        ProgressView()
                                            .tint(RQColors.background)
                                    } else {
                                        Text("Save")
                                            .font(RQTypography.headline)
                                    }
                                }
                                .foregroundColor(RQColors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, RQSpacing.md)
                                .background(RQColors.accent)
                                .cornerRadius(RQRadius.medium)
                            }
                            .disabled(isSavingSocial)
                        }
                    }

                    // Settings Section
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.lg) {
                            Text("Settings")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            // Weight Unit
                            Button {
                                showWeightUnitPicker = true
                            } label: {
                                settingsRow(
                                    icon: "scalemass",
                                    title: "Weight Unit",
                                    value: viewModel.profile?.weightUnit.displayName ?? "lbs"
                                )
                            }

                            Divider().background(RQColors.surfaceTertiary)

                            // Rest Timer
                            Button {
                                showRestTimerPicker = true
                            } label: {
                                settingsRow(
                                    icon: "timer",
                                    title: "Default Rest Timer",
                                    value: "\(viewModel.profile?.restTimerDefault ?? 90)s"
                                )
                            }

                            Divider().background(RQColors.surfaceTertiary)

                            // Notifications
                            NavigationLink {
                                NotificationSettingsView()
                            } label: {
                                settingsRow(
                                    icon: "bell",
                                    title: "Notifications",
                                    value: ""
                                )
                            }

                        }
                    }

                    // Goals
                    NavigationLink {
                        GoalSettingView()
                    } label: {
                        RQCard {
                            HStack {
                                Image(systemName: "target")
                                    .font(.system(size: 16))
                                    .foregroundColor(RQColors.accent)
                                    .frame(width: 24)

                                Text("My Goals")
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                    }

                    // Sign Out
                    RQButton(title: "Sign Out", style: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                    .padding(.top, RQSpacing.lg)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(RQColors.background)
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.loadProfile()
                username = viewModel.profile?.username ?? ""
                bio = viewModel.profile?.bio ?? ""
            }
            .confirmationDialog("Weight Unit", isPresented: $showWeightUnitPicker) {
                Button("lbs") {
                    Task { await viewModel.updateWeightUnit(.lbs) }
                }
                Button("kg") {
                    Task { await viewModel.updateWeightUnit(.kg) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Rest Timer", isPresented: $showRestTimerPicker) {
                ForEach(restTimerOptions, id: \.self) { seconds in
                    Button("\(seconds)s (\(seconds / 60)m \(seconds % 60)s)") {
                        Task { await viewModel.updateRestTimer(seconds) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(RQColors.accent)
                .frame(width: 24)

            Text(title)
                .font(RQTypography.body)
                .foregroundColor(RQColors.textPrimary)

            Spacer()

            Text(value)
                .font(RQTypography.body)
                .foregroundColor(RQColors.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(RQColors.textTertiary)
        }
    }
}
