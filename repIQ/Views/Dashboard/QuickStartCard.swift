import SwiftUI

struct QuickStartCard: View {
    /// Day name from the user's most recent completed workout. When non-nil,
    /// the card surfaces a "Repeat" primary action that re-runs that exact day.
    var lastDayName: String?
    var lastTemplateName: String?
    var lastCompletedAt: Date?

    var onStartWorkout: () -> Void
    var onRepeatLast: (() -> Void)?

    var body: some View {
        if let lastDayName, let onRepeatLast {
            repeatCard(dayName: lastDayName, onRepeat: onRepeatLast)
        } else {
            startCard
        }
    }

    // MARK: - Default state (no prior workout)

    private var startCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("Ready to train?")
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)
                        Text("Start a workout from your templates")
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.textSecondary)
                    }
                    Spacer()
                }

                RQButton(title: "Start Workout") {
                    onStartWorkout()
                }
            }
        }
    }

    // MARK: - Repeat-last state

    private func repeatCard(dayName: String, onRepeat: @escaping () -> Void) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("Pick up where you left off")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Text(dayName)
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: RQSpacing.xs) {
                            if let templateName = lastTemplateName {
                                Text(templateName)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                    .lineLimit(1)
                            }
                            if let completedAt = lastCompletedAt {
                                if lastTemplateName != nil {
                                    Text("·")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                }
                                Text(completedAt.relativeDisplay)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(RQColors.accent)
                }

                RQButton(title: "Repeat Workout") {
                    onRepeat()
                }

                Button {
                    onStartWorkout()
                } label: {
                    Text("Pick a different template")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.xs)
                }
            }
        }
    }
}
