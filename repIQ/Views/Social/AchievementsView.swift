import SwiftUI

/// Unified achievements view replacing both BadgesView and MilestoneCelebrationView.
/// Shows tiered Duolingo-style progression for all achievement categories.
struct AchievementsView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var selectedCategory: AchievementCategory?
    @State private var expandedId: String?

    private var filteredAchievements: [Achievement] {
        guard let category = selectedCategory else { return viewModel.achievements }
        return viewModel.achievements.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Summary
                summaryHeader

                // Category filter
                categoryPicker

                // Achievement cards
                if filteredAchievements.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: RQSpacing.md) {
                        ForEach(filteredAchievements) { achievement in
                            achievementCard(achievement)
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: RQSpacing.xl) {
            VStack(spacing: RQSpacing.xxs) {
                Text("\(viewModel.totalUnlockedTiers)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.accent)
                Text("UNLOCKED")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)
            }

            VStack(spacing: RQSpacing.xxs) {
                Text("\(viewModel.totalTiers)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textSecondary)
                Text("TOTAL")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)
            }

            Spacer()

            // Progress ring
            let progress = viewModel.totalTiers == 0 ? 0.0 : Double(viewModel.totalUnlockedTiers) / Double(viewModel.totalTiers)
            ZStack {
                Circle()
                    .stroke(RQColors.surfaceTertiary, lineWidth: 4)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(RQColors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textPrimary)
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RQSpacing.sm) {
                categoryPill(title: "All", category: nil)
                ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                    categoryPill(title: category.displayName, category: category)
                }
            }
        }
    }

    private func categoryPill(title: String, category: AchievementCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(RQTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(isSelected ? RQColors.accent : RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.large)
        }
    }

    // MARK: - Achievement Card

    private func achievementCard(_ achievement: Achievement) -> some View {
        let isExpanded = expandedId == achievement.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedId = isExpanded ? nil : achievement.id
            }
        } label: {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                // Header row
                HStack(spacing: RQSpacing.md) {
                    // Icon
                    Image(systemName: achievement.icon)
                        .font(.system(size: 22))
                        .foregroundColor(achievement.currentTier?.color ?? RQColors.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(
                            (achievement.currentTier?.color ?? RQColors.textTertiary).opacity(0.15)
                        )
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        HStack(spacing: RQSpacing.sm) {
                            Text(achievement.name)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)

                            if let tier = achievement.currentTier {
                                Text(tier.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(tier.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tier.color.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }

                        Text(achievement.description)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.textTertiary)
                }

                // Progress bar toward next tier
                if let nextTier = achievement.nextTier {
                    VStack(spacing: RQSpacing.xs) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(RQColors.surfaceTertiary)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(nextTier.tier.color)
                                    .frame(width: geo.size.width * achievement.progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text("\(Int(achievement.currentValue))/\(Int(nextTier.threshold))")
                                .font(RQTypography.label)
                                .foregroundColor(RQColors.textSecondary)

                            Spacer()

                            Text(nextTier.title)
                                .font(RQTypography.label)
                                .foregroundColor(nextTier.tier.color)
                        }
                    }
                } else {
                    // Fully completed
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.success)
                        Text("All tiers unlocked")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.success)
                        Spacer()
                    }
                }

                // Tier dots
                tierDots(achievement)

                // Expanded tier details
                if isExpanded {
                    Divider().background(RQColors.surfaceTertiary)

                    VStack(spacing: RQSpacing.sm) {
                        ForEach(achievement.tiers) { tier in
                            tierDetailRow(tier)
                        }
                    }
                }
            }
            .padding(RQSpacing.cardPadding)
            .background(RQColors.surfacePrimary)
            .cornerRadius(RQRadius.medium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier Dots

    private func tierDots(_ achievement: Achievement) -> some View {
        HStack(spacing: RQSpacing.sm) {
            ForEach(achievement.tiers) { tier in
                Circle()
                    .fill(tier.isUnlocked ? tier.tier.color : RQColors.surfaceTertiary)
                    .frame(width: 10, height: 10)
                    .overlay(
                        tier.isUnlocked
                            ? Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(RQColors.background)
                            : nil
                    )
            }

            Spacer()
        }
    }

    // MARK: - Tier Detail Row

    private func tierDetailRow(_ tier: TierLevel) -> some View {
        HStack(spacing: RQSpacing.md) {
            Image(systemName: tier.tier.icon)
                .font(.system(size: 14))
                .foregroundColor(tier.isUnlocked ? tier.tier.color : RQColors.textTertiary.opacity(0.5))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(tier.title)
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(tier.isUnlocked ? RQColors.textPrimary : RQColors.textTertiary)

                Text("Reach \(Int(tier.threshold))")
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer()

            if tier.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(tier.tier.color)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary.opacity(0.5))
            }
        }
        .padding(.vertical, RQSpacing.xs)
        .opacity(tier.isUnlocked ? 1.0 : 0.6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("No achievements yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Start training to unlock achievements and track your progress.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }
}
