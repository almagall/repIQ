import SwiftUI

/// A branded card rendered off-screen for sharing to Instagram Stories / social media.
/// Designed at 1080×1920 aspect ratio (9:16) with dark theme.
struct WorkoutShareCard: View {
    let summary: WorkoutSummaryData

    private let cardWidth: CGFloat = 390
    private let cardHeight: CGFloat = 693 // ~9:16 aspect

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient accent bar
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [RQColors.accent, RQColors.accent.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)

            VStack(spacing: 24) {
                // Header: App branding + workout name
                VStack(spacing: 8) {
                    Text("repIQ")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(RQColors.accent)

                    if !summary.workoutName.isEmpty {
                        Text(summary.workoutName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.top, 28)

                // Stats row
                HStack(spacing: 0) {
                    shareStatPill(value: formattedDuration, label: "Duration", icon: "clock")
                    shareDivider
                    shareStatPill(value: "\(summary.totalSets)", label: "Sets", icon: "number")
                    shareDivider
                    shareStatPill(value: formattedVolume, label: "Volume", icon: "scalemass")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)

                // PRs (if any)
                let displayPRs = summary.newPRs.filter { $0.recordType != .volume }
                if !displayPRs.isEmpty {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.warning)
                            Text("PERSONAL RECORDS")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(RQColors.warning)
                        }

                        ForEach(displayPRs.prefix(3)) { pr in
                            HStack {
                                Text(pr.exerciseName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatPRValue(pr))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(RQColors.warning)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Exercise list
                VStack(spacing: 6) {
                    HStack {
                        Text("EXERCISES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Color.white.opacity(0.4))
                        Spacer()
                    }

                    ForEach(summary.exerciseSummaries.prefix(8)) { exercise in
                        HStack {
                            // Mode indicator dot
                            Circle()
                                .fill(exercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                                .frame(width: 6, height: 6)

                            Text(exercise.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            if exercise.topWeight > 0 {
                                Text("\(formatWeight(exercise.topWeight)) x \(exercise.topReps)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                    }

                    if summary.exerciseSummaries.count > 8 {
                        Text("+\(summary.exerciseSummaries.count - 8) more")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 4)

                Spacer()

                // Streak badge (if active)
                if summary.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.warning)
                        Text("\(summary.currentStreak) day streak")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(RQColors.warning)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RQColors.warning.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Footer
                Text("Track your gains with repIQ")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.25))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
        )
    }

    // MARK: - Components

    private func shareStatPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(RQColors.accent)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color.white.opacity(0.4))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var shareDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 36)
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

    private func formatPRValue(_ pr: PRSummary) -> String {
        switch pr.recordType {
        case .weight: return "\(formatWeight(pr.value)) lbs"
        case .reps: return "\(Int(pr.value)) reps"
        case .estimated1rm: return "\(formatWeight(pr.value)) lbs e1RM"
        case .volume: return String(format: "%.0f lbs", pr.value)
        }
    }
}
