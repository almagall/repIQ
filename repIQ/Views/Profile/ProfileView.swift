import SwiftUI
import Supabase

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showWeightUnitPicker = false
    @State private var showRestTimerPicker = false
    @State private var username = ""
    @State private var isSavingSocial = false
    @State private var gymName: String?

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
                                if let username = viewModel.profile?.username, !username.isEmpty {
                                    Text(username)
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                } else {
                                    Text(viewModel.profile?.displayName ?? "User")
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                }

                                if let gym = gymName, !gym.isEmpty {
                                    HStack(spacing: RQSpacing.xs) {
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(RQColors.textTertiary)
                                        Text(gym)
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }
                            }
                            Spacer()
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
                                    value: viewModel.profile?.safeWeightUnit.displayName ?? "lbs"
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

                            Divider().background(RQColors.surfaceTertiary)

                            // Privacy
                            NavigationLink {
                                PrivacySettingsView()
                            } label: {
                                settingsRow(
                                    icon: "lock.shield",
                                    title: "Privacy",
                                    value: ""
                                )
                            }

                            Divider().background(RQColors.surfaceTertiary)

                            // My Gym
                            NavigationLink {
                                GymSearchView()
                            } label: {
                                settingsRow(
                                    icon: "building.2",
                                    title: "My Gym",
                                    value: ""
                                )
                            }

                            Divider().background(RQColors.surfaceTertiary)

                            // Account
                            NavigationLink {
                                AccountView(profile: viewModel.profile)
                            } label: {
                                settingsRow(
                                    icon: "person.crop.circle",
                                    title: "Account",
                                    value: ""
                                )
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
                // Load gym name directly
                if let userId = try? await supabase.auth.session.user.id {
                    struct GymField: Decodable {
                        let gymName: String?
                        enum CodingKeys: String, CodingKey { case gymName = "gym_name" }
                    }
                    let field: GymField? = try? await supabase.from("profiles")
                        .select("gym_name")
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    gymName = field?.gymName
                }
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
