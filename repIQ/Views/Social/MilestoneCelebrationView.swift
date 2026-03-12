import SwiftUI

/// Displays user milestones and friend milestone celebrations.
struct MilestoneCelebrationView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var myMilestones: [UserMilestone] = []
    @State private var friendMilestones: [UserMilestone] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // My milestones
                myMilestonesSection

                // Friend celebrations
                if !friendMilestones.isEmpty {
                    friendCelebrationsSection
                }

                // All milestones grid
                allMilestonesGrid
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMilestones()
        }
    }

    // MARK: - My Milestones

    private var myMilestonesSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("YOUR MILESTONES")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if myMilestones.isEmpty && !isLoading {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: "medal")
                            .font(.system(size: 24))
                            .foregroundColor(RQColors.textTertiary)
                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text("No milestones yet")
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textSecondary)
                            Text("Keep training — your first milestone is around the corner!")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(myMilestones) { milestone in
                    milestoneCard(milestone, isMine: true)
                }
            }
        }
    }

    // MARK: - Friend Celebrations

    private var friendCelebrationsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("FRIEND CELEBRATIONS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            ForEach(friendMilestones) { milestone in
                milestoneCard(milestone, isMine: false)
            }
        }
    }

    // MARK: - All Milestones Grid

    private var allMilestonesGrid: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("ALL MILESTONES")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            let earnedTypes = Set(myMilestones.map(\.milestoneType))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
                ForEach(MilestoneType.allCases, id: \.self) { type in
                    let isEarned = earnedTypes.contains(type)
                    milestoneGridItem(type: type, isEarned: isEarned)
                }
            }
        }
    }

    // MARK: - Components

    private func milestoneCard(_ milestone: UserMilestone, isMine: Bool) -> some View {
        let type = milestone.milestoneType
        return RQCard {
            HStack(spacing: RQSpacing.md) {
                // Icon with celebration ring
                ZStack {
                    Circle()
                        .fill(RQColors.warning.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: type.icon)
                        .font(.system(size: 22))
                        .foregroundColor(RQColors.warning)
                }

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(type.displayName)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text(type.description)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                    Text(formatDate(milestone.achievedAt))
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                if isMine {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(RQColors.success)
                }
            }
        }
    }

    private func milestoneGridItem(type: MilestoneType, isEarned: Bool) -> some View {
        VStack(spacing: RQSpacing.sm) {
            Image(systemName: type.icon)
                .font(.system(size: 24))
                .foregroundColor(isEarned ? RQColors.warning : RQColors.textTertiary.opacity(0.4))

            Text(type.displayName)
                .font(RQTypography.caption)
                .foregroundColor(isEarned ? RQColors.textPrimary : RQColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(RQSpacing.md)
        .background(isEarned ? RQColors.warning.opacity(0.08) : RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .stroke(isEarned ? RQColors.warning.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Loading

    private func loadMilestones() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        let service = MatchmakingService()
        do {
            async let myResult = service.fetchMilestones(userId: userId)
            async let friendResult = service.fetchFriendMilestones(friendIds: viewModel.friendIds)
            let (my, friends) = try await (myResult, friendResult)
            myMilestones = my
            friendMilestones = friends
        } catch {
            // Silently fail
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
