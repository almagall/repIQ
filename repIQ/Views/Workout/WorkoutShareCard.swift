import SwiftUI

/// A branded card rendered for sharing to Instagram Stories / social media.
/// Uses the app's design system (RQColors, RQTypography, RQCard borders).
/// Designed at 9:16 aspect ratio with the app's dark theme.
struct WorkoutShareCard: View {
    let summary: WorkoutSummaryData

    private let cardWidth: CGFloat = 390
    private let cardHeight: CGFloat = 693

    var body: some View {
        VStack(spacing: 0) {
            // Top accent line
            Rectangle()
                .fill(RQColors.accent)
                .frame(height: 3)

            VStack(spacing: RQSpacing.lg) {
                // Header: Day name + Date
                VStack(spacing: RQSpacing.sm) {
                    let displayName = summary.dayName.isEmpty ? summary.workoutName : summary.dayName
                    if !displayName.isEmpty {
                        Text(displayName)
                            .font(RQTypography.title2)
                            .foregroundColor(RQColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    Text(formattedDate)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }
                .padding(.top, RQSpacing.xl)

                // Stats row — bordered cards matching app theme
                HStack(spacing: RQSpacing.md) {
                    shareStatCard(value: formattedDuration, label: "DURATION", icon: "clock")
                    shareStatCard(value: "\(summary.totalSets)", label: "SETS", icon: "number")
                    shareStatCard(value: formattedVolume, label: "VOLUME", icon: "scalemass")
                }

                // Streak (if active)
                if summary.currentStreak > 0 {
                    HStack(spacing: RQSpacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.warning)
                        Text("\(summary.currentStreak) day streak")
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.warning)
                    }
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, RQSpacing.sm)
                    .background(RQColors.warning.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Exercise list with heaviest set + PR badges
                VStack(spacing: RQSpacing.sm) {
                    HStack {
                        Text("EXERCISES")
                            .font(RQTypography.label)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textTertiary)
                        Spacer()
                        Text("BEST SET")
                            .font(RQTypography.label)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    ForEach(summary.exerciseSummaries.prefix(10)) { exercise in
                        exerciseRow(exercise)
                    }

                    if summary.exerciseSummaries.count > 10 {
                        Text("+\(summary.exerciseSummaries.count - 10) more")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Spacer()

                // Footer: repIQ branding
                VStack(spacing: RQSpacing.xs) {
                    Text("repIQ")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(RQColors.accent)

                    Text("Train smarter")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(.bottom, RQSpacing.xl)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                .fill(RQColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                        .stroke(RQColors.textTertiary, lineWidth: 1)
                )
        )
    }

    // MARK: - Components

    private func shareStatCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: RQSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(RQColors.accent)

            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)

            Text(label)
                .font(RQTypography.label)
                .tracking(1)
                .foregroundColor(RQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RQSpacing.md)
        .background(Color.clear)
        .cornerRadius(RQSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                .stroke(RQColors.textTertiary, lineWidth: 1)
        )
    }

    private func exerciseRow(_ exercise: WorkoutSummaryData.ExerciseSummary) -> some View {
        HStack(spacing: RQSpacing.sm) {
            // Training mode bar
            RoundedRectangle(cornerRadius: 1)
                .fill(exercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: RQSpacing.xs) {
                    Text(exercise.name)
                        .font(RQTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)

                    // PR badge
                    if let pr = exercisePR(for: exercise.name) {
                        HStack(spacing: 2) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 7))
                            Text(pr.recordType.shortLabel)
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(RQColors.warning)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RQColors.warning.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Text("\(exercise.setsCompleted) sets")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer()

            // Heaviest set
            if exercise.topWeight > 0 {
                Text("\(formatWeight(exercise.topWeight)) x \(exercise.topReps)")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textSecondary)
            } else if exercise.topReps > 0 {
                Text("BW x \(exercise.topReps)")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - PR Lookup

    private func exercisePR(for exerciseName: String) -> PRSummary? {
        summary.newPRs.first { $0.exerciseName == exerciseName && $0.recordType != .volume }
    }

    // MARK: - Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: summary.workoutDate)
    }

    private var formattedDuration: String {
        let hours = summary.duration / 3600
        let minutes = (summary.duration % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var formattedVolume: String {
        if summary.totalVolume >= 1000 {
            return String(format: "%.1fk", summary.totalVolume / 1000)
        }
        return String(format: "%.0f", summary.totalVolume)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
