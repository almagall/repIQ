import SwiftUI

struct PRCelebrationView: View {
    let celebration: PRCelebration
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            // Icon
            Image(systemName: celebration.prType.icon)
                .font(.system(size: 40))
                .foregroundColor(RQColors.warning)
                .padding(.top, RQSpacing.lg)

            // Title
            Text(celebration.prType.label)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(RQColors.warning)

            // Exercise name
            Text(celebration.exerciseName)
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)

            // New vs Previous
            VStack(spacing: RQSpacing.md) {
                // New PR
                VStack(spacing: RQSpacing.xxs) {
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(RQColors.success)
                    Text(celebration.newValue)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(RQColors.textPrimary)
                }

                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RQColors.success)

                // Previous PR
                VStack(spacing: RQSpacing.xxs) {
                    Text("PREVIOUS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(RQColors.textTertiary)
                    Text(celebration.previousValue)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(RQColors.textSecondary)

                    if let date = celebration.previousDate {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            }
            .padding(RQSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.large)

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Text("LET'S GO")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
}
