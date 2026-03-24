import SwiftUI

/// Activity feed showing workout completions, PRs, and milestones from friends.
struct FeedView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var commentText: [UUID: String] = [:]
    @State private var showingComments: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: RQSpacing.lg) {
                if viewModel.isLoading && viewModel.feedItems.isEmpty {
                    loadingState
                } else if friendFeedItems.isEmpty {
                    emptyState
                } else {
                    ForEach(friendFeedItems) { item in
                        feedItemCard(item)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Feed Item Card

    private func feedItemCard(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            // Header: user info + time
            HStack(spacing: RQSpacing.md) {
                // Avatar placeholder
                Circle()
                    .fill(RQColors.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(avatarInitial(for: item))
                            .font(RQTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(RQColors.accent)
                    )

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(displayName(for: item))
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    Text(timeAgo(item.createdAt))
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                // Event type icon
                feedTypeIcon(item.itemType)
            }

            // Content
            feedItemContent(item)

            // Stats row (for workout items)
            if item.itemType == .workoutCompleted {
                workoutStatsRow(item.data)
            }

            Divider()
                .overlay(RQColors.surfaceTertiary)

            // Action row
            HStack(spacing: RQSpacing.xl) {
                // Fist bump button
                Button {
                    Task { await viewModel.toggleFistBump(feedItemId: item.id) }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: hasFistBumped(item) ? "hands.clap.fill" : "hands.clap")
                            .font(.system(size: 14))
                        Text("\(item.reactions?.count ?? 0)")
                            .font(RQTypography.caption)
                    }
                    .foregroundColor(hasFistBumped(item) ? RQColors.warning : RQColors.textTertiary)
                }

                // Comment button
                Button {
                    if showingComments == item.id {
                        showingComments = nil
                    } else {
                        showingComments = item.id
                    }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("\(item.comments?.count ?? 0)")
                            .font(RQTypography.caption)
                    }
                    .foregroundColor(RQColors.textTertiary)
                }

                Spacer()
            }

            // Comments section
            if showingComments == item.id {
                commentsSection(item)
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Feed Content

    @ViewBuilder
    private func feedItemContent(_ item: FeedItem) -> some View {
        switch item.itemType {
        case .workoutCompleted:
            workoutCompletedContent(item)

        case .prAchieved:
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundColor(RQColors.warning)
                    let count = item.data.prCount ?? 0
                    Text(count > 1 ? "Hit \(count) new personal records!" : "Hit a new personal record!")
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                        .fontWeight(.semibold)
                }

                if let prDetails = item.data.prDetails, !prDetails.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(prDetails.enumerated()), id: \.offset) { index, pr in
                            HStack(spacing: RQSpacing.sm) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(RQColors.warning)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pr.exerciseName)
                                        .font(RQTypography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(RQColors.textPrimary)

                                    Text(pr.displayType)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(RQColors.textTertiary)
                                }

                                Spacer()

                                Text(pr.displayValue)
                                    .font(RQTypography.numbersSmall)
                                    .foregroundColor(RQColors.accent)
                            }
                            .padding(.vertical, RQSpacing.xs)

                            if index < prDetails.count - 1 {
                                Divider()
                                    .background(RQColors.surfaceTertiary)
                                    .padding(.leading, 30)
                            }
                        }
                    }
                    .padding(RQSpacing.sm)
                    .background(RQColors.surfaceTertiary.opacity(0.5))
                    .cornerRadius(RQRadius.small)
                }
            }

        case .streakMilestone:
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "flame.fill")
                    .foregroundColor(RQColors.warning)
                if let days = item.data.streakDays {
                    Text("\(days)-day training streak!")
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                        .fontWeight(.semibold)
                }
            }

        case .badgeEarned:
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "medal.fill")
                    .foregroundColor(RQColors.accent)
                if let badge = item.data.badgeName {
                    Text("Earned the \"\(badge)\" badge")
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                }
            }

        case .leaguePromoted:
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(RQColors.success)
                if let tier = item.data.leagueTier {
                    Text("Promoted to \(tier.capitalized) league!")
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                        .fontWeight(.semibold)
                }
            }

        case .challengeWon:
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(RQColors.warning)
                Text("Won a challenge!")
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Workout Completed Content

    @State private var expandedWorkouts: Set<UUID> = []

    private func workoutCompletedContent(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            // Workout title
            if let dayName = item.data.workoutDayName, !dayName.isEmpty {
                Text("Completed \(dayName)")
                    .font(RQTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.textPrimary)
            } else {
                Text("Completed a workout")
                    .font(RQTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.textPrimary)
            }

            // Exercise list — expandable
            if let exercises = item.data.exerciseNames, !exercises.isEmpty {
                let isExpanded = expandedWorkouts.contains(item.id)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedWorkouts.remove(item.id)
                        } else {
                            expandedWorkouts.insert(item.id)
                        }
                    }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RQColors.accent)
                    }
                }

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(Array(exercises.enumerated()), id: \.offset) { index, name in
                            HStack(spacing: RQSpacing.sm) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(RQColors.accent)
                                    .frame(width: 2, height: 20)

                                Text(name)
                                    .font(RQTypography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(RQColors.textSecondary)

                                Spacer()
                            }
                            .padding(.vertical, RQSpacing.xxs)

                            if index < exercises.count - 1 {
                                Divider()
                                    .background(RQColors.surfaceTertiary)
                                    .padding(.leading, RQSpacing.lg)
                            }
                        }
                    }
                    .padding(RQSpacing.sm)
                    .background(RQColors.surfaceTertiary.opacity(0.5))
                    .cornerRadius(RQRadius.small)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Workout Stats

    private func workoutStatsRow(_ data: FeedItemData) -> some View {
        HStack(spacing: RQSpacing.lg) {
            if let sets = data.totalSets {
                statPill(icon: "number", value: "\(sets)", label: "sets")
            }
            if let volume = data.totalVolume {
                statPill(icon: "scalemass.fill", value: formatVolume(volume), label: "volume")
            }
            if let duration = data.duration {
                statPill(icon: "clock.fill", value: formatDuration(duration), label: "duration")
            }
            if let prs = data.prCount, prs > 0 {
                statPill(icon: "star.fill", value: "\(prs)", label: "PRs")
            }
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            HStack(spacing: RQSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .font(RQTypography.numbersSmall)
            }
            .foregroundColor(RQColors.textPrimary)

            Text(label)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .textCase(.uppercase)
        }
    }

    // MARK: - Comments

    private func commentsSection(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            if let comments = item.comments, !comments.isEmpty {
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: RQSpacing.sm) {
                        Circle()
                            .fill(RQColors.surfaceTertiary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(String((comment.userProfile?.displayName ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(RQColors.textSecondary)
                            )

                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(comment.userProfile?.displayName ?? "User")
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.textPrimary)
                            Text(comment.content)
                                .font(RQTypography.footnote)
                                .foregroundColor(RQColors.textSecondary)
                        }

                        Spacer()
                    }
                }
            }

            // Comment input
            HStack(spacing: RQSpacing.sm) {
                TextField("Add a comment...", text: Binding(
                    get: { commentText[item.id] ?? "" },
                    set: { commentText[item.id] = $0 }
                ))
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textPrimary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.large)

                if let text = commentText[item.id], !text.isEmpty {
                    Button {
                        Task {
                            await viewModel.addComment(feedItemId: item.id, content: text)
                            commentText[item.id] = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(RQColors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Feed Type Icon

    @ViewBuilder
    private func feedTypeIcon(_ type: FeedItemType) -> some View {
        let icon: String = {
            switch type {
            case .workoutCompleted: return "figure.strengthtraining.traditional"
            case .prAchieved: return "star.fill"
            case .streakMilestone: return "flame.fill"
            case .badgeEarned: return "medal.fill"
            case .leaguePromoted: return "arrow.up.circle.fill"
            case .challengeWon: return "trophy.fill"
            }
        }()

        let color: Color = {
            switch type {
            case .workoutCompleted: return RQColors.success
            case .prAchieved: return RQColors.warning
            case .streakMilestone: return RQColors.warning
            case .badgeEarned: return RQColors.accent
            case .leaguePromoted: return RQColors.success
            case .challengeWon: return RQColors.warning
            }
        }()

        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }

    // MARK: - Empty / Loading States

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("No activity yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Add friends to see their workouts and PRs here.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    private var loadingState: some View {
        VStack(spacing: RQSpacing.lg) {
            ProgressView()
                .tint(RQColors.accent)
            Text("Loading feed...")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Helpers

    /// Feed items from friends only (excludes current user's own items)
    private var friendFeedItems: [FeedItem] {
        viewModel.feedItems.filter { $0.userId != viewModel.currentUserId }
    }

    private func displayName(for item: FeedItem) -> String {
        if let username = item.userProfile?.username, !username.isEmpty {
            return username
        }
        if let displayName = item.userProfile?.displayName, !displayName.isEmpty {
            return displayName
        }
        return "User"
    }

    private func avatarInitial(for item: FeedItem) -> String {
        let name = displayName(for: item)
        return String(name.prefix(1)).uppercased()
    }

    private func hasFistBumped(_ item: FeedItem) -> Bool {
        guard let userId = viewModel.currentUserId else { return false }
        return item.reactions?.contains { $0.userId == userId } ?? false
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return String(format: "%dh %dm", minutes / 60, minutes % 60)
        }
        return "\(minutes)m"
    }
}
