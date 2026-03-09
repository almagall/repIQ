import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummaryData
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    // Header
                    VStack(spacing: RQSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(RQColors.success)

                        Text("Workout Complete!")
                            .font(RQTypography.title1)
                            .foregroundColor(RQColors.textPrimary)
                    }
                    .padding(.top, RQSpacing.xl)

                    // Stats row
                    HStack(spacing: RQSpacing.lg) {
                        statCard(
                            label: "Duration",
                            value: formattedDuration,
                            icon: "clock"
                        )
                        statCard(
                            label: "Sets",
                            value: "\(summary.totalSets)",
                            icon: "number"
                        )
                        statCard(
                            label: "Volume",
                            value: formattedVolume,
                            icon: "scalemass"
                        )
                    }

                    // PR celebrations
                    if !summary.newPRs.isEmpty {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("New Personal Records")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            ForEach(summary.newPRs) { pr in
                                prCard(pr)
                            }
                        }
                    }

                    // Exercise breakdown
                    if !summary.exerciseSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("Exercise Breakdown")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            ForEach(summary.exerciseSummaries) { exercise in
                                exerciseCard(exercise)
                            }
                        }
                    }

                    // Next session progression
                    if !summary.progressionDecisions.isEmpty {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("Next Session")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            ForEach(summary.progressionDecisions) { progression in
                                progressionCard(progression)
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.accent)
                }
            }
        }
    }

    // MARK: - Components

    private func statCard(label: String, value: String, icon: String) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.accent)

                Text(value)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func exerciseCard(_ exercise: WorkoutSummaryData.ExerciseSummary) -> some View {
        RQCard {
            HStack {
                // Mode indicator bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(exercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(exercise.name)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    HStack(spacing: RQSpacing.sm) {
                        Text("\(exercise.setsCompleted) sets")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)

                        if exercise.topWeight > 0 {
                            Text("·")
                                .foregroundColor(RQColors.textTertiary)
                            Text("Top: \(formatWeight(exercise.topWeight)) × \(exercise.topReps)")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                    Text(formatVolume(exercise.totalVolume))
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.accent)
                    Text("volume")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    private func prCard(_ pr: PRSummary) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.warning)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(pr.exerciseName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    Text(pr.recordType.displayName)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                Text(formatPRValue(pr.value, type: pr.recordType))
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.warning)
            }
        }
    }

    private func progressionCard(_ progression: ProgressionSummary) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: decisionIcon(progression.decision))
                        .font(.system(size: 14))
                        .foregroundColor(decisionColor(progression.decision))

                    Text(progression.exerciseName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    Text("\(formatWeight(progression.targetWeight)) × \(progression.targetReps)")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                }

                Text(progression.reasoning)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
            }
        }
    }

    private func decisionIcon(_ decision: ProgressionDecision) -> String {
        switch decision {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .increaseReps: return "arrow.up.right.circle.fill"
        case .maintain: return "arrow.right.circle.fill"
        case .deload, .deloadVolume: return "arrow.down.circle.fill"
        }
    }

    private func decisionColor(_ decision: ProgressionDecision) -> Color {
        switch decision {
        case .increaseWeight: return RQColors.success
        case .increaseReps: return RQColors.accent
        case .maintain: return RQColors.warning
        case .deload, .deloadVolume: return RQColors.error
        }
    }

    private func formatPRValue(_ value: Double, type: RecordType) -> String {
        switch type {
        case .weight:
            return "\(formatWeight(value)) lbs"
        case .reps:
            return "\(Int(value)) reps"
        case .volume:
            return formatVolume(value)
        case .estimated1rm:
            return "\(formatWeight(value)) lbs"
        }
    }

    // MARK: - Formatting

    private var formattedDuration: String {
        let hours = summary.duration / 3600
        let minutes = (summary.duration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var formattedVolume: String {
        formatVolume(summary.totalVolume)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
