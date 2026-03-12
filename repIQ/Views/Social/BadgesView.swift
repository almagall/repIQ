import SwiftUI

/// Badge collection showing earned and unearned badges.
struct BadgesView: View {
    @Bindable var viewModel: SocialViewModel

    private let columns = [
        GridItem(.flexible(), spacing: RQSpacing.md),
        GridItem(.flexible(), spacing: RQSpacing.md),
        GridItem(.flexible(), spacing: RQSpacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Summary
                badgeSummary

                // Earned badges
                if !viewModel.earnedBadges.isEmpty {
                    badgeSection(
                        title: "EARNED",
                        badges: viewModel.earnedBadges.compactMap(\.badge),
                        isEarned: true
                    )
                }

                // Unearned badges by category
                ForEach(BadgeCategory.allCases, id: \.rawValue) { category in
                    let categoryBadges = viewModel.unearnedBadges.filter { $0.category == category }
                    if !categoryBadges.isEmpty {
                        badgeSection(
                            title: categoryDisplayName(category),
                            badges: categoryBadges,
                            isEarned: false
                        )
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Summary

    private var badgeSummary: some View {
        HStack(spacing: RQSpacing.xl) {
            VStack(spacing: RQSpacing.xxs) {
                Text("\(viewModel.earnedBadges.count)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.accent)
                Text("EARNED")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)
            }

            VStack(spacing: RQSpacing.xxs) {
                Text("\(viewModel.allBadges.count)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textSecondary)
                Text("TOTAL")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
                    .tracking(1.5)
            }

            Spacer()

            // Progress ring
            let progress = viewModel.allBadges.isEmpty ? 0.0 : Double(viewModel.earnedBadges.count) / Double(viewModel.allBadges.count)
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

    // MARK: - Badge Section

    private func badgeSection(title: String, badges: [Badge], isEarned: Bool) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text(title)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .tracking(1.5)

            LazyVGrid(columns: columns, spacing: RQSpacing.md) {
                ForEach(badges) { badge in
                    badgeCard(badge, isEarned: isEarned)
                }
            }
        }
    }

    private func badgeCard(_ badge: Badge, isEarned: Bool) -> some View {
        VStack(spacing: RQSpacing.sm) {
            // Icon
            Image(systemName: badge.icon)
                .font(.system(size: 24))
                .foregroundColor(isEarned ? categoryColor(badge.category) : RQColors.textTertiary.opacity(0.5))
                .frame(width: 48, height: 48)
                .background(
                    isEarned
                        ? categoryColor(badge.category).opacity(0.15)
                        : RQColors.surfaceTertiary.opacity(0.5)
                )
                .clipShape(Circle())

            // Name
            Text(badge.name)
                .font(RQTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(isEarned ? RQColors.textPrimary : RQColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Description
            Text(badge.description)
                .font(.system(size: 9))
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
        .opacity(isEarned ? 1.0 : 0.6)
    }

    // MARK: - Helpers

    private func categoryColor(_ category: BadgeCategory) -> Color {
        switch category {
        case .volume: return RQColors.hypertrophy
        case .consistency: return RQColors.success
        case .strength: return RQColors.warning
        case .social: return RQColors.accent
        case .intelligence: return RQColors.info
        }
    }

    private func categoryDisplayName(_ category: BadgeCategory) -> String {
        switch category {
        case .volume: return "VOLUME"
        case .consistency: return "CONSISTENCY"
        case .strength: return "STRENGTH"
        case .social: return "SOCIAL"
        case .intelligence: return "INTELLIGENCE"
        }
    }
}

extension BadgeCategory: CaseIterable {
    static var allCases: [BadgeCategory] {
        [.volume, .consistency, .strength, .social, .intelligence]
    }
}
