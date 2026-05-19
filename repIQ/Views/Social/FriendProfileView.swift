import SwiftUI

/// Friend detail screen reached by tapping a friend card. Surfaces the
/// friend's public social stats (league tier, IQ, streak) and the actions
/// — Progression Race, Challenge, Remove — that were otherwise unreachable
/// from the friend list.
struct FriendProfileView: View {
    @Bindable var viewModel: SocialViewModel
    let friendship: Friendship

    @State private var profile: SocialProfile?
    @State private var isLoading = true
    @State private var showCreateChallenge = false
    @Environment(\.dismiss) private var dismiss

    private let service = SocialService()

    private var displayName: String {
        friendship.friendProfile?.username ?? "User"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                header

                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxl)
                } else {
                    statsRow
                    actionsSection
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView(viewModel: viewModel, preselectedFriend: friendship)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: RQSpacing.md) {
            Circle()
                .fill(RQColors.accent.opacity(0.2))
                .frame(width: 84, height: 84)
                .overlay(
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(RQColors.accent)
                )

            VStack(spacing: RQSpacing.xxs) {
                Text(displayName)
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.textPrimary)
                if let username = friendship.friendProfile?.username {
                    Text("@\(username)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RQSpacing.lg)
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        RQCard {
            HStack(spacing: RQSpacing.lg) {
                statBlock(value: "\(profile?.totalIQ ?? 0)",
                          label: "IQ POINTS",
                          color: RQColors.accent)
                Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                statBlock(value: profile?.leagueTier?.displayName ?? "—",
                          label: "LEAGUE",
                          color: tierColor(profile?.leagueTier))
                Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                statBlock(value: "\(profile?.currentStreak ?? 0)",
                          label: "STREAK",
                          color: RQColors.warning)
            }
        }
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(value)
                .font(RQTypography.numbers)
                .foregroundColor(color)
            Text(label)
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func tierColor(_ tier: LeagueTier?) -> Color {
        switch tier {
        case .elite, .diamond: return RQColors.accent
        case .platinum, .gold: return RQColors.warning
        default: return RQColors.textSecondary
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: RQSpacing.sm) {
            NavigationLink(value: SocialDestination.progressionRace(friendship)) {
                actionRow(icon: "chart.line.uptrend.xyaxis",
                          title: "Progression Race",
                          subtitle: "Compare your gains side-by-side")
            }

            Button {
                showCreateChallenge = true
            } label: {
                actionRow(icon: "flag.checkered",
                          title: "Start a Challenge",
                          subtitle: "Head-to-head over 7 days")
            }

            Button(role: .destructive) {
                Task {
                    await viewModel.removeFriend(friendship)
                    dismiss()
                }
            } label: {
                actionRow(icon: "person.badge.minus",
                          title: "Remove Friend",
                          subtitle: nil,
                          destructive: true)
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String?, destructive: Bool = false) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(destructive ? RQColors.error : RQColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(title)
                        .font(RQTypography.headline)
                        .foregroundColor(destructive ? RQColors.error : RQColors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Spacer()

                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Load

    private func loadProfile() async {
        isLoading = true
        do {
            profile = try await service.fetchSocialProfile(userId: friendship.friendId)
        } catch {
            profile = nil
        }
        isLoading = false
    }
}
