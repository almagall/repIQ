import SwiftUI

struct PRCelebrationView: View {
    let celebration: PRCelebration
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            // Icon
            Image(systemName: celebration.prType.icon)
                .font(.system(size: 36))
                .foregroundColor(RQColors.warning)
                .padding(.top, RQSpacing.lg)

            // Title
            Text(celebration.prType.label)
                .font(RQTypography.title1)
                .foregroundColor(RQColors.warning)

            // Exercise name
            Text(celebration.exerciseName)
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)

            // Delta + percentage badge
            if let delta = celebration.delta {
                HStack(spacing: RQSpacing.sm) {
                    Text(delta)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.success)

                    if let pct = celebration.percentImprovement, pct > 0 {
                        Text(String(format: "%.1f%% increase", pct))
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.success)
                            .padding(.horizontal, RQSpacing.sm)
                            .padding(.vertical, RQSpacing.xxs)
                            .background(RQColors.success.opacity(0.15))
                            .cornerRadius(RQRadius.small)
                    }
                }
            }

            // New vs Previous comparison
            VStack(spacing: RQSpacing.md) {
                // New PR
                VStack(spacing: RQSpacing.xxs) {
                    Text("NEW")
                        .font(RQTypography.label)
                        .tracking(1.5)
                        .foregroundColor(RQColors.success)
                    Text(celebration.newValue)
                        .font(RQTypography.numbers)
                        .foregroundColor(RQColors.textPrimary)
                }

                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RQColors.success)

                // Previous PR
                VStack(spacing: RQSpacing.xxs) {
                    Text("PREVIOUS")
                        .font(RQTypography.label)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textTertiary)
                    Text(celebration.previousValue)
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textSecondary)

                    if let date = celebration.previousDate {
                        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                        Text("\(days) days ago · \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            }
            .padding(RQSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.large)

            // Estimated 1RM (weight PRs only)
            if let est1RM = celebration.estimated1RM {
                HStack(spacing: RQSpacing.sm) {
                    Text("Est. 1RM")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                    Text("\(formatWeight(est1RM)) lbs")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.accent)
                }
                .padding(.horizontal, RQSpacing.lg)
                .padding(.vertical, RQSpacing.sm)
                .background(RQColors.accent.opacity(0.1))
                .cornerRadius(RQRadius.medium)
            }

            // Continue button
            Button {
                onDismiss()
            } label: {
                Text("Continue")
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.warning)
                    .cornerRadius(RQRadius.large)
            }
        }
        .padding(RQSpacing.xl)
        .background(RQColors.background)
        .cornerRadius(RQRadius.extraLarge)
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .padding(.horizontal, RQSpacing.xl)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
