import SwiftUI

/// Main Social tab — hub for feed, friends, leagues, challenges, discover, and community.
struct SocialTabView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var selectedSection: SocialSection = .feed
    @State private var showSetupSheet = false
    @State private var showAddFriends = false

    enum SocialSection: String, CaseIterable {
        case feed = "Feed"
        case friends = "Friends"
        case challenges = "Challenges"
        case discover = "Discover"

        var icon: String {
            switch self {
            case .feed: return "bubble.left.and.bubble.right.fill"
            case .friends: return "person.2.fill"
            case .challenges: return "bolt.fill"
            case .discover: return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section picker
                sectionPicker

                // Setup banner
                if let profile = viewModel.socialProfile,
                   (profile.username ?? "").isEmpty {
                    socialSetupBanner
                }

                // Content
                Group {
                    switch selectedSection {
                    case .feed:
                        FeedView(viewModel: viewModel)
                    case .friends:
                        FriendsView(viewModel: viewModel)
                    case .challenges:
                        ChallengesView(viewModel: viewModel)
                    case .discover:
                        discoverSection
                    }
                }
            }
            .background(RQColors.background)
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: RQSpacing.md) {
                        // Add friend button
                        Button {
                            showAddFriends = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(RQColors.accent)
                                .overlay(alignment: .topTrailing) {
                                    if !viewModel.pendingRequests.isEmpty {
                                        Text("\(viewModel.pendingRequests.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(RQColors.error)
                                            .clipShape(Capsule())
                                            .offset(x: 6, y: -8)
                                    }
                                }
                        }

                        // Profile avatar
                        NavigationLink {
                            SocialProfileView(viewModel: viewModel)
                        } label: {
                            Circle()
                                .fill(RQColors.accent.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(String((viewModel.socialProfile?.displayName ?? "?").prefix(1)).uppercased())
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(RQColors.accent)
                                )
                        }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    // Streak only (IQ moved to Leagues)
                    if viewModel.currentStreak > 0 {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(RQColors.warning)
                            Text("\(viewModel.currentStreak)")
                                .font(RQTypography.numbersSmall)
                                .foregroundColor(RQColors.textPrimary)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSocialData()
            }
            .refreshable {
                await viewModel.loadSocialData()
            }
            .sheet(isPresented: $showSetupSheet) {
                SocialSetupSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddFriends) {
                AddFriendsSheet(viewModel: viewModel)
            }
            .overlay {
                if let achievement = viewModel.celebrationAchievement {
                    AchievementCelebrationOverlay(achievement: achievement) {
                        viewModel.celebrationAchievement = nil
                    }
                }
            }
        }
    }

    // MARK: - Setup Banner

    private var socialSetupBanner: some View {
        Button {
            showSetupSheet = true
        } label: {
            HStack(spacing: RQSpacing.md) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(RQColors.accent)
                    .frame(width: 3, height: 44)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22))
                    .foregroundColor(RQColors.accent)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text("Complete Your Profile")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text("Set a username so friends can find you")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(RQSpacing.cardPadding)
            .background(RQColors.accent.opacity(0.08))
            .cornerRadius(RQRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.medium)
                    .stroke(RQColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.top, RQSpacing.sm)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(SocialSection.allCases, id: \.rawValue) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14))

                        Text(section.rawValue)
                            .font(.system(size: 10, weight: .semibold))

                        Rectangle()
                            .fill(selectedSection == section ? RQColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundColor(selectedSection == section ? RQColors.accent : RQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(RQColors.surfacePrimary)
    }

    // MARK: - Discover Section

    private var discoverSection: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Quick links grid — consolidated to 3 cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
                    discoverLink(
                        title: "Achievements",
                        subtitle: "Track progress",
                        icon: "trophy.fill",
                        color: RQColors.warning
                    ) {
                        AchievementsView(viewModel: viewModel)
                    }

                    discoverLink(
                        title: "Monthly Wrapped",
                        subtitle: "Training report",
                        icon: "chart.bar.doc.horizontal.fill",
                        color: RQColors.hypertrophy
                    ) {
                        MonthlyWrappedView(viewModel: viewModel)
                    }

                    discoverLink(
                        title: "Weekly Digest",
                        subtitle: "Friend activity",
                        icon: "newspaper.fill",
                        color: RQColors.success
                    ) {
                        WeeklyDigestView(viewModel: viewModel)
                    }
                }

                // Coaching nudges
                if !viewModel.coachingNudges.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("INSIGHTS FOR YOU")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        ForEach(viewModel.coachingNudges) { nudge in
                            nudgeCard(nudge)
                        }
                    }
                }

                // Progression Race shortcuts
                if !viewModel.friends.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("PROGRESSION RACE")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Text("Compare your E1RM progression with a friend")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        ForEach(viewModel.friends.prefix(5)) { friend in
                            NavigationLink {
                                ProgressionRaceView(viewModel: viewModel, friend: friend)
                            } label: {
                                RQCard {
                                    HStack(spacing: RQSpacing.md) {
                                        Circle()
                                            .fill(RQColors.accent.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Text(String((friend.friendProfile?.displayName ?? "?").prefix(1)).uppercased())
                                                    .font(RQTypography.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(RQColors.accent)
                                            )

                                        Text(friend.friendProfile?.displayName ?? "Friend")
                                            .font(RQTypography.body)
                                            .foregroundColor(RQColors.textPrimary)

                                        Spacer()

                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 14))
                                            .foregroundColor(RQColors.accent)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
    }

    private func discoverLink<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            RQCard {
                VStack(spacing: RQSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)

                    Text(title)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    Text(subtitle)
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.sm)
            }
        }
    }

    private func nudgeCard(_ nudge: CoachingNudge) -> some View {
        let color: Color = {
            switch nudge.accentColor {
            case "accent": return RQColors.accent
            case "success": return RQColors.success
            case "warning": return RQColors.warning
            case "error": return RQColors.error
            default: return RQColors.accent
            }
        }()

        return RQCard {
            HStack(alignment: .top, spacing: RQSpacing.md) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3)

                Image(systemName: nudge.icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text(nudge.title)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text(nudge.message)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
        }
    }
}
