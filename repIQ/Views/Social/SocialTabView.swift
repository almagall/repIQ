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
        case gym = "Gym"
        case challenges = "Challenges"

        var icon: String {
            switch self {
            case .feed: return "bubble.left.and.bubble.right.fill"
            case .friends: return "person.2.fill"
            case .gym: return "building.2.fill"
            case .challenges: return "bolt.fill"
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
                    case .gym:
                        GymHubView(viewModel: viewModel)
                    case .challenges:
                        ChallengesView(viewModel: viewModel)
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
                        }

                        // Profile avatar removed — profile accessible via Profile tab
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
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14))

                            if section == .friends && !viewModel.pendingRequests.isEmpty {
                                Text("\(viewModel.pendingRequests.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(RQColors.error)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }

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

    // Discover tab removed — Achievements moved to Home, Monthly Report moved to Progress
}
