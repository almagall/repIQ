import SwiftUI

/// Spotify-style monthly training report card with shareable card.
struct MonthlyWrappedView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var wrapped: MonthlyWrapped?
    @State private var pastWrapped: [MonthlyWrapped] = []
    @State private var isLoading = false
    @State private var selectedWrapped: MonthlyWrapped?

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else if let w = selectedWrapped ?? wrapped {
                    wrappedCard(w)

                    // Past months
                    if !pastWrapped.isEmpty {
                        pastSection
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Monthly Wrapped")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWrapped()
        }
    }

    // MARK: - Wrapped Card

    private func wrappedCard(_ w: MonthlyWrapped) -> some View {
        VStack(spacing: RQSpacing.lg) {
            // Month header
            VStack(spacing: RQSpacing.sm) {
                Text(monthLabel(w.monthStart))
                    .font(RQTypography.title1)
                    .foregroundColor(RQColors.textPrimary)
                Text("YOUR TRAINING WRAPPED")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundColor(RQColors.accent)
            }

            // Hero stats
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
                heroStat(value: "\(w.totalSessions)", label: "Workouts", icon: "figure.strengthtraining.traditional", color: RQColors.accent)
                heroStat(value: formatVolume(w.totalVolume), label: "Volume Lifted", icon: "scalemass.fill", color: RQColors.success)
                heroStat(value: "\(w.totalSets)", label: "Total Sets", icon: "number", color: RQColors.hypertrophy)
                heroStat(value: "\(w.totalPRs)", label: "Personal Records", icon: "star.fill", color: RQColors.warning)
            }

            // Key insights
            insightsSection(w)

            // Biggest PR
            if let prExercise = w.biggestPRExercise, let prValue = w.biggestPRValue {
                RQCard {
                    VStack(spacing: RQSpacing.sm) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 28))
                            .foregroundColor(RQColors.warning)
                        Text("Biggest PR")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textTertiary)
                        Text(prExercise)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                        Text("\(formatWeight(prValue)) lbs")
                            .font(RQTypography.numbers)
                            .foregroundColor(RQColors.warning)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Additional stats
            additionalStats(w)
        }
    }

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(value)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)

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

    private func insightsSection(_ w: MonthlyWrapped) -> some View {
        VStack(spacing: RQSpacing.md) {
            // Top exercise
            if let topExercise = w.topExerciseName {
                insightRow(
                    icon: "flame.fill",
                    title: "Most Performed",
                    detail: topExercise,
                    subtitle: w.topExerciseVolume.map { "\(formatVolume($0)) volume" },
                    color: RQColors.warning
                )
            }

            // Most consistent muscle
            if let muscle = w.mostConsistentMuscle {
                insightRow(
                    icon: "checkmark.circle.fill",
                    title: "Most Consistent",
                    detail: muscle.capitalized,
                    subtitle: "muscle group",
                    color: RQColors.success
                )
            }

            // Favorite day
            if let day = w.favoriteDay {
                insightRow(
                    icon: "calendar",
                    title: "Favorite Day",
                    detail: day,
                    subtitle: "most workouts on this day",
                    color: RQColors.accent
                )
            }

            // Longest streak
            if w.longestStreak > 0 {
                insightRow(
                    icon: "flame.fill",
                    title: "Longest Streak",
                    detail: "\(w.longestStreak) days",
                    subtitle: nil,
                    color: RQColors.warning
                )
            }
        }
    }

    private func insightRow(icon: String, title: String, detail: String, subtitle: String?, color: Color) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(title)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                    Text(detail)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }

    private func additionalStats(_ w: MonthlyWrapped) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("DETAILS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if let duration = w.avgSessionDuration {
                detailRow(label: "Avg Session Duration", value: formatDuration(duration))
            }

            if let rank = w.percentileRank {
                detailRow(label: "Percentile Rank", value: "Top \(100 - rank)%")
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(RQTypography.body)
                .foregroundColor(RQColors.textSecondary)
            Spacer()
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
        }
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Past Section

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("PAST MONTHS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            ForEach(pastWrapped) { past in
                Button {
                    selectedWrapped = past
                } label: {
                    RQCard {
                        HStack(spacing: RQSpacing.md) {
                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text(monthLabel(past.monthStart))
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                HStack(spacing: RQSpacing.md) {
                                    Label("\(past.totalSessions) workouts", systemImage: "figure.strengthtraining.traditional")
                                    Label("\(past.totalPRs) PRs", systemImage: "star.fill")
                                }
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("No wrapped available")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Complete workouts this month and your wrapped will be generated at the end of the month.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Helpers

    private func loadWrapped() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        let service = DigestService()
        do {
            wrapped = try await service.generateMonthlyWrapped(userId: userId)
            pastWrapped = try await service.fetchWrappedHistory(userId: userId)
            // Remove current from past
            if let current = wrapped {
                pastWrapped.removeAll { $0.id == current.id }
            }
        } catch {
            // Silently fail
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        }
        if volume >= 1000 {
            return String(format: "%.0fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
