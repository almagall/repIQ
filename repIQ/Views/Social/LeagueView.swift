import SwiftUI

/// League leaderboard with tier progression.
/// Users earn IQ points through actual training — no shortcuts.
struct LeagueView: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // User's league card
                userLeagueCard

                // Leaderboard
                leaderboardSection
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
    }

    // MARK: - User League Card

    private var userLeagueCard: some View {
        VStack(spacing: RQSpacing.lg) {
            // Tier badge
            HStack(spacing: RQSpacing.md) {
                Image(systemName: viewModel.currentTier.icon)
                    .font(.system(size: 28))
                    .foregroundColor(tierColor(viewModel.currentTier))

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(viewModel.currentTier.displayName)
                        .font(RQTypography.title2)
                        .foregroundColor(RQColors.textPrimary)
                    Text("LEAGUE")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .tracking(1.5)
                }

                Spacer()

                // Total IQ
                VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                    Text("\(viewModel.totalIQ)")
                        .font(RQTypography.numbers)
                        .foregroundColor(RQColors.accent)
                    Text("TOTAL IQ")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .tracking(1.5)
                }
            }

            // Tier progression
            tierProgressionBar

            // How IQ is earned
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("HOW TO EARN IQ")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)

                iqExplanationRow(icon: "checkmark.circle", points: "+1", label: "Per completed set")
                iqExplanationRow(icon: "target", points: "+3", label: "Per target hit")
                iqExplanationRow(icon: "flag.fill", points: "+10", label: "Session completed")
                iqExplanationRow(icon: "star.fill", points: "+25", label: "New personal record")
                iqExplanationRow(icon: "flame.fill", points: "+15", label: "Streak bonus (3+ days)")
                iqExplanationRow(icon: "trophy.fill", points: "+50", label: "Challenge won")
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    private func iqExplanationRow(icon: String, points: String, label: String) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(RQColors.accent)
                .frame(width: 20)

            Text(points)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.accent)
                .frame(width: 30, alignment: .trailing)

            Text(label)
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Tier Progression Bar

    private var tierProgressionBar: some View {
        let tiers = LeagueTier.allCases
        let currentIndex = tiers.firstIndex(of: viewModel.currentTier) ?? 0

        return HStack(spacing: 0) {
            ForEach(tiers.indices, id: \.self) { index in
                let tier = tiers[index]
                let isReached = index <= currentIndex
                let isCurrent = index == currentIndex

                HStack(spacing: 0) {
                    // Tier icon node
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(isReached ? tierColor(tier).opacity(0.15) : RQColors.surfaceTertiary.opacity(0.3))
                                .frame(width: isCurrent ? 36 : 28, height: isCurrent ? 36 : 28)

                            Image(systemName: tier.icon)
                                .font(.system(size: isCurrent ? 16 : 12, weight: .semibold))
                                .foregroundColor(isReached ? tierColor(tier) : RQColors.textTertiary.opacity(0.4))
                        }

                        Text(tier.displayName)
                            .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isReached ? tierColor(tier) : RQColors.textTertiary.opacity(0.5))
                    }

                    // Connecting line
                    if index < tiers.count - 1 {
                        Rectangle()
                            .fill(index < currentIndex ? tierColor(tier) : RQColors.surfaceTertiary)
                            .frame(height: 2)
                            .padding(.bottom, 18) // align with icon center
                    }
                }
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("LEADERBOARD")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)

                Spacer()

                Text("\(viewModel.currentTier.displayName) League")
                    .font(RQTypography.caption)
                    .foregroundColor(tierColor(viewModel.currentTier))
            }

            if viewModel.leaderboard.isEmpty {
                Text("No players in this league yet")
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.textTertiary)
                    .padding(.vertical, RQSpacing.xl)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, user in
                    leaderboardRow(position: index + 1, user: user)
                }
            }

            // Promotion / demotion info
            if viewModel.leaderboard.count >= 10 {
                HStack(spacing: RQSpacing.lg) {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.success)
                        Text("Top 5 promote")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.error)
                        Text("Bottom 5 demote")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Spacer()
                }
                .padding(.top, RQSpacing.sm)
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    private func leaderboardRow(position: Int, user: SocialProfile) -> some View {
        let isUser = user.id == viewModel.currentUserId
        let total = viewModel.leaderboard.count

        return HStack(spacing: RQSpacing.md) {
            // Position
            positionBadge(position: position, total: total)

            // Avatar
            Circle()
                .fill(isUser ? RQColors.accent.opacity(0.3) : RQColors.surfaceTertiary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String((user.username ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isUser ? RQColors.accent : RQColors.textSecondary)
                )

            // Name
            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(isUser ? "You" : (user.username ?? "User"))
                    .font(RQTypography.headline)
                    .foregroundColor(isUser ? RQColors.accent : RQColors.textPrimary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            Spacer()

            // IQ
            Text("\(user.totalIQ)")
                .font(RQTypography.numbersSmall)
                .foregroundColor(isUser ? RQColors.accent : RQColors.textPrimary)

            Text("IQ")
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(.vertical, RQSpacing.sm)
        .padding(.horizontal, RQSpacing.sm)
        .background(isUser ? RQColors.accent.opacity(0.08) : Color.clear)
        .cornerRadius(RQRadius.small)
    }

    private func positionBadge(position: Int, total: Int) -> some View {
        let color: Color = {
            if position <= 3 {
                switch position {
                case 1: return RQColors.warning
                case 2: return Color(hex: "C0C0C0")
                case 3: return Color(hex: "CD7F32")
                default: return RQColors.textTertiary
                }
            }
            if position <= 5 { return RQColors.success }
            if position > max(total - 5, 5) { return RQColors.error }
            return RQColors.textTertiary
        }()

        return Text("\(position)")
            .font(RQTypography.numbersSmall)
            .foregroundColor(color)
            .frame(width: 28)
    }

    // MARK: - Helpers

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
