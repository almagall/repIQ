import SwiftUI
import Supabase

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var socialViewModel = SocialViewModel()
    @State private var showWeightUnitPicker = false
    @State private var showRestTimerPicker = false
    @State private var username = ""
    @State private var isSavingSocial = false
    @State private var gymName: String?
    @State private var gymAddress: String?
    @State private var showSignOutConfirmation = false
    @AppStorage(AppConstants.UserDefaultsKeys.smartRestTimerEnabled)
    private var smartRestTimerEnabled = AppConstants.Defaults.smartRestTimerEnabled

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
                                    Text("User")
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                }

                                if let gym = gymName, !gym.isEmpty {
                                    HStack(spacing: RQSpacing.xs) {
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(RQColors.textPrimary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(gym)
                                                .font(RQTypography.caption)
                                                .foregroundColor(RQColors.textPrimary)
                                            if let address = gymAddress, !address.isEmpty {
                                                Text(address)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(RQColors.textPrimary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                    }

                    // My Stats — surfaces the user's public-profile data
                    // (league, IQ, streak, badges) that previously had no
                    // home on the Profile tab.
                    myStatsCard

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

                            // Smart Rest Timer
                            Toggle(isOn: $smartRestTimerEnabled) {
                                HStack {
                                    Image(systemName: "bolt.heart")
                                        .font(.system(size: 16))
                                        .foregroundColor(RQColors.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Smart Rest Timer")
                                            .font(RQTypography.body)
                                            .foregroundColor(RQColors.textPrimary)
                                        Text("Adds rest after hard sets, trims it after easy ones")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .tint(RQColors.accent)

                            Divider().background(RQColors.surfaceTertiary)

                            // Body & Health
                            NavigationLink {
                                BodyProfileView(viewModel: viewModel)
                            } label: {
                                settingsRow(
                                    icon: "figure",
                                    title: "Body & Health",
                                    value: bodyProfileSummary
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
                        showSignOutConfirmation = true
                    }
                    .padding(.top, RQSpacing.lg)
                    .confirmationDialog(
                        "Are you sure you want to sign out?",
                        isPresented: $showSignOutConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Sign Out", role: .destructive) {
                            Task { await viewModel.signOut() }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
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
                await socialViewModel.loadSocialData()
                // Load gym info directly
                if let userId = try? await supabase.auth.session.user.id {
                    struct GymFields: Decodable {
                        let gymName: String?
                        let gymAddress: String?
                        enum CodingKeys: String, CodingKey {
                            case gymName = "gym_name"
                            case gymAddress = "gym_address"
                        }
                    }
                    let fields: GymFields? = try? await supabase.from("profiles")
                        .select("gym_name, gym_address")
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    gymName = fields?.gymName
                    gymAddress = fields?.gymAddress
                }
            }
            .navigationDestination(for: SocialDestination.self) { destination in
                switch destination {
                case .league:
                    LeagueView(viewModel: socialViewModel)
                        .navigationTitle("Leagues")
                        .navigationBarTitleDisplayMode(.inline)
                case .achievements:
                    AchievementsView(viewModel: socialViewModel)
                case .socialProfile:
                    SocialProfileView(viewModel: socialViewModel)
                case .challenges:
                    ChallengesView(viewModel: socialViewModel)
                        .navigationTitle("Challenges")
                        .navigationBarTitleDisplayMode(.inline)
                case .weeklyDigest:
                    WeeklyDigestView(viewModel: socialViewModel)
                case .matchmaking:
                    MatchmakingView(viewModel: socialViewModel)
                case .friendProfile(let friendship):
                    FriendProfileView(viewModel: socialViewModel, friendship: friendship)
                case .progressionRace(let friendship):
                    ProgressionRaceView(viewModel: socialViewModel, friend: friendship)
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

    // MARK: - My Stats card

    private var myStatsCard: some View {
        VStack(spacing: RQSpacing.md) {
            NavigationLink(value: SocialDestination.league) {
                HStack(spacing: RQSpacing.lg) {
                    statCell(icon: socialViewModel.currentTier.icon,
                             color: RQColors.accent,
                             value: socialViewModel.currentTier.displayName,
                             label: "LEAGUE")
                    Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                    statCell(icon: "bolt.fill",
                             color: RQColors.accent,
                             value: "\(socialViewModel.totalIQ)",
                             label: "IQ")
                    Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                    statCell(icon: "flame.fill",
                             color: RQColors.warning,
                             value: "\(socialViewModel.currentStreak)",
                             label: "STREAK")
                }
                .padding(RQSpacing.cardPadding)
                .background(RQColors.surfacePrimary)
                .cornerRadius(RQRadius.medium)
            }
            .buttonStyle(.plain)

            HStack(spacing: RQSpacing.sm) {
                NavigationLink(value: SocialDestination.achievements) {
                    profileQuickAction(icon: "medal.fill",
                                       title: "Achievements",
                                       count: socialViewModel.earnedBadges.count)
                }
                .buttonStyle(.plain)

                NavigationLink(value: SocialDestination.socialProfile) {
                    profileQuickAction(icon: "person.crop.circle",
                                       title: "Public Profile",
                                       count: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileQuickAction(icon: String, title: String, count: Int?) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(RQColors.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.textPrimary)
                if let count {
                    Text("\(count) earned")
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    /// Single short summary string for the Body & Health row. Picks the
    /// most informative captured field so the user can glance at what's
    /// already filled in. Empty when nothing is set.
    private var bodyProfileSummary: String {
        guard let profile = viewModel.profile else { return "" }
        let unit = profile.safeWeightUnit
        var parts: [String] = []
        if let kg = profile.bodyWeightKg, kg > 0 {
            let value = unit == .lbs ? kg / 0.45359237 : kg
            parts.append(String(format: "%.0f \(unit.displayName)", value))
        }
        if let injuries = profile.injuries, !injuries.isEmpty {
            parts.append("\(injuries.count) injur\(injuries.count == 1 ? "y" : "ies")")
        }
        return parts.joined(separator: " · ")
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
