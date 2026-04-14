import SwiftUI

/// A compact recap card that surfaces the user's most recent completed workout
/// at the top of the Progress tab. Tapping it navigates to the full session
/// detail view. Answers the most natural question on the Progress tab:
/// "How did I do last time?"
struct LastWorkoutRecapCard: View {
    let recap: LastWorkoutRecap

    private var workoutTitle: String {
        switch (recap.templateName, recap.dayName) {
        case let (template?, day?):
            return "\(template) · \(day)"
        case let (template?, nil):
            return template
        case let (nil, day?):
            return day
        case (nil, nil):
            return "Workout"
        }
    }

    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: recap.completedAt), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 14 { return "1 week ago" }
        return "\(days / 7) weeks ago"
    }

    private var durationLabel: String {
        let minutes = recap.durationSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }

    private var volumeLabel: String {
        if recap.totalVolume >= 10_000 {
            return String(format: "%.1fK", recap.totalVolume / 1000)
        }
        return String(format: "%.0f", recap.totalVolume)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("LAST WORKOUT")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
            }

            NavigationLink(value: recap.sessionId) {
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        // Title row
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text(workoutTitle)
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                    .lineLimit(1)
                                Text(relativeDate)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            Spacer()
                            if recap.prCount > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("\(recap.prCount) PR\(recap.prCount > 1 ? "S" : "")")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(RQColors.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RQColors.warning)
                                .cornerRadius(RQRadius.small)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(RQColors.textTertiary)
                        }

                        Divider().background(RQColors.surfaceTertiary)

                        // Stats row
                        HStack(spacing: 0) {
                            statTile(value: durationLabel, label: "DURATION")
                            statTile(value: "\(recap.workingSets)", label: "SETS")
                            statTile(value: volumeLabel, label: "VOLUME")
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
