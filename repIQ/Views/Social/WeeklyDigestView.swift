import SwiftUI

/// In-app weekly summary of friend circle activity.
struct WeeklyDigestView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var currentDigest: WeeklyDigest?
    @State private var pastDigests: [WeeklyDigest] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else if let digest = currentDigest {
                    currentDigestCard(digest)

                    // Past digests
                    if !pastDigests.isEmpty {
                        pastDigestsSection
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Weekly Digest")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDigests()
        }
    }

    // MARK: - Current Digest

    private func currentDigestCard(_ digest: WeeklyDigest) -> some View {
        VStack(spacing: RQSpacing.lg) {
            // Header
            VStack(spacing: RQSpacing.sm) {
                Text("THIS WEEK IN YOUR CIRCLE")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.accent)

                Text(weekLabel(digest.weekStart))
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
                digestStat(
                    icon: "person.2.fill",
                    value: "\(digest.friendsTrained)",
                    label: "Friends Trained",
                    color: RQColors.accent
                )
                digestStat(
                    icon: "figure.strengthtraining.traditional",
                    value: "\(digest.totalWorkouts)",
                    label: "Total Workouts",
                    color: RQColors.success
                )
                digestStat(
                    icon: "star.fill",
                    value: "\(digest.totalPRs)",
                    label: "PRs Hit",
                    color: RQColors.warning
                )
                digestStat(
                    icon: "trophy.fill",
                    value: topPerformerName(digest),
                    label: "Top Performer",
                    color: RQColors.warning
                )
            }

            // Highlights
            if let highlights = digest.highlights, !highlights.isEmpty {
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("HIGHLIGHTS")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)

                    ForEach(Array(highlights.enumerated()), id: \.offset) { _, highlight in
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: highlightIcon(highlight.type))
                                .font(.system(size: 14))
                                .foregroundColor(RQColors.accent)

                            Text(highlight.message)
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                        }
                        .padding(RQSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RQColors.surfacePrimary)
                        .cornerRadius(RQRadius.medium)
                    }
                }
            }

            // League changes
            if let changes = digest.leagueChanges, !changes.isEmpty {
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("LEAGUE MOVES")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)

                    ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: change.toTier > change.fromTier ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundColor(change.toTier > change.fromTier ? RQColors.success : RQColors.error)

                            Text("\(change.username) moved to \(change.toTier.displayName)")
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func digestStat(icon: String, value: String, label: String, color: Color) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Text(value)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(RQColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Past Digests

    private var pastDigestsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("PAST WEEKS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            ForEach(pastDigests) { digest in
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(weekLabel(digest.weekStart))
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)

                            HStack(spacing: RQSpacing.md) {
                                Label("\(digest.friendsTrained) friends", systemImage: "person.2")
                                Label("\(digest.totalWorkouts) workouts", systemImage: "figure.strengthtraining.traditional")
                                Label("\(digest.totalPRs) PRs", systemImage: "star.fill")
                            }
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                        }

                        Spacer()

                        if !digest.isRead {
                            Circle()
                                .fill(RQColors.accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "newspaper")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("No digest yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Your weekly digest will appear here with a summary of friend activity.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Helpers

    private func loadDigests() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        let service = DigestService()
        do {
            // Generate current week's digest
            currentDigest = try await service.generateWeeklyDigest(
                userId: userId,
                friendIds: viewModel.friendIds
            )

            // Mark as read
            if let digest = currentDigest, !digest.isRead {
                try? await service.markRead(digestId: digest.id)
            }

            // Load past digests
            let all = try await service.fetchDigests(userId: userId, limit: 10)
            pastDigests = Array(all.dropFirst()) // Skip current week
        } catch {
            // Silently fail
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
        return "\(f.string(from: date)) – \(f.string(from: endDate))"
    }

    private func topPerformerName(_ digest: WeeklyDigest) -> String {
        if let performerId = digest.topPerformerId {
            let friend = viewModel.friends.first { $0.friendId == performerId }
            return friend?.friendProfile?.displayName ?? "—"
        }
        return "—"
    }

    private func highlightIcon(_ type: String) -> String {
        switch type {
        case "prs": return "star.fill"
        case "streak": return "flame.fill"
        case "volume": return "scalemass.fill"
        default: return "sparkles"
        }
    }
}

// LeagueTier Comparable conformance for comparison
extension LeagueTier: Comparable {
    static func < (lhs: LeagueTier, rhs: LeagueTier) -> Bool {
        let order: [LeagueTier] = [.bronze, .silver, .gold, .platinum, .diamond, .elite]
        guard let lhsIdx = order.firstIndex(of: lhs),
              let rhsIdx = order.firstIndex(of: rhs) else { return false }
        return lhsIdx < rhsIdx
    }
}
