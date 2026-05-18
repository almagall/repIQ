import SwiftUI

/// The hero card at the top of the Progress tab showing the user's top
/// most-logged lifts scoped by workout day, with current estimated 1RM,
/// 4-week delta, velocity status, a tiny sparkline, and a coaching narrative.
struct StrengthTrajectoryCard: View {
    let lifts: [TopLiftTrajectory]
    /// Bodyweight in lbs, used to classify each lift against the strength
    /// standards. Nil hides the tier chip.
    var bodyweightLbs: Double? = nil
    /// Profile sex ("male"/"female"/"prefer_not_to_say"). Drives which
    /// standards table is consulted.
    var profileSex: String? = nil
    var onSelect: ((TopLiftTrajectory) -> Void)? = nil
    var onBrowseAll: (() -> Void)? = nil
    var onCompare: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            RQSectionHeader(
                title: "STRENGTH TRAJECTORY",
                trailing: lifts.count >= 2 ? AnyView(compareButton) : nil
            )

            if lifts.isEmpty {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 22))
                            .foregroundColor(RQColors.textTertiary)
                        Text("Log a few more sessions to see your top lifts trending")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                        Spacer()
                    }
                }
            } else {
                RQCard {
                    VStack(spacing: RQSpacing.md) {
                        ForEach(Array(lifts.enumerated()), id: \.element.id) { index, lift in
                            liftRow(lift)
                            if index < lifts.count - 1 {
                                Divider()
                                    .background(RQColors.surfaceTertiary)
                            }
                        }

                        // Browse All Exercises row
                        Divider()
                            .background(RQColors.surfaceTertiary)

                        Button {
                            onBrowseAll?()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 13))
                                    .foregroundColor(RQColors.accent)
                                Text("Browse All Exercises")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var compareButton: some View {
        Button {
            onCompare?()
        } label: {
            HStack(spacing: 2) {
                Text("COMPARE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(RQColors.accent)
        }
        .buttonStyle(.plain)
    }

    private func liftRow(_ lift: TopLiftTrajectory) -> some View {
        Button {
            onSelect?(lift)
        } label: {
            HStack(alignment: .top, spacing: RQSpacing.md) {
                // Left: exercise name + day context + narrative
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    HStack(spacing: RQSpacing.xs) {
                        Text(lift.exerciseName)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                            .lineLimit(1)

                        if let dayName = lift.dayName {
                            Text("· \(dayName)")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: lift.velocityStatus.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(lift.velocityStatus.color)
                        Text(lift.narrative)
                            .font(.system(size: 11))
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }

                    // 4-week projection (only when reliable + meaningful gain)
                    if let projection = lift.projection,
                       projection.projectedGain >= 3 {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(RQColors.accent)
                            Text("On pace for \(formatWeight(projection.projectedE1RM)) in 4 weeks")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.accent.opacity(0.85))
                                .lineLimit(1)
                        }
                    }

                    // Strength tier chip (squat/bench/deadlift/OHP/row only).
                    // Shown when we have the user's bodyweight on file.
                    if let bw = bodyweightLbs,
                       let classification = StrengthStandards.classify(
                           exerciseName: lift.exerciseName,
                           e1RM: lift.currentE1RM,
                           bodyweightLbs: bw,
                           sex: profileSex
                       ) {
                        strengthTierChip(classification: classification, bodyweightLbs: bw)
                    }
                }

                Spacer(minLength: RQSpacing.sm)

                // Middle: sparkline
                if lift.sparkline.count >= 2 {
                    sparkline(lift.sparkline, color: lift.velocityStatus.color)
                        .frame(width: 48, height: 24)
                }

                // Right: e1RM + delta. Bodyweight-only movements (Tricep Dips,
                // Pull-Ups, Push-Ups) record weight = 0 so the e1RM formula
                // collapses; show the rep count instead with a small "BW"
                // qualifier so the row reads correctly.
                VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                    if lift.isBodyweightOnly {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(lift.bestReps)")
                                .font(RQTypography.numbersSmall)
                                .foregroundColor(RQColors.textPrimary)
                            Text("reps")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Text("BW")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(RQColors.textTertiary)
                    } else {
                        Text(formatWeight(lift.currentE1RM))
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.textPrimary)
                        if abs(lift.fourWeekDelta) >= 1 {
                            HStack(spacing: 2) {
                                Image(systemName: lift.fourWeekDelta >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                Text(String(format: "%.0f lb", abs(lift.fourWeekDelta)))
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(lift.fourWeekDelta >= 0 ? RQColors.success : RQColors.warning)
                        } else {
                            Text("—")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func strengthTierChip(
        classification: (category: StrengthStandards.Category, tier: StrengthStandards.Tier, ratio: Double),
        bodyweightLbs: Double
    ) -> some View {
        let nextTarget = StrengthStandards.nextThreshold(
            category: classification.category,
            tier: classification.tier,
            bodyweightLbs: bodyweightLbs,
            sex: nil // ignored — already encoded in the classifying call
        )

        return HStack(spacing: RQSpacing.xs) {
            HStack(spacing: 3) {
                Circle()
                    .fill(classification.tier.color)
                    .frame(width: 5, height: 5)
                Text(classification.tier.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(classification.tier.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.small)
                    .stroke(classification.tier.color.opacity(0.6), lineWidth: 0.5)
            )

            Text(String(format: "%.2f× BW", classification.ratio))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(RQColors.textTertiary)

            if let target = nextTarget {
                Text("· \(Int(target.rounded())) lb to next")
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func sparkline(_ values: [Double], color: Color) -> some View {
        GeometryReader { geo in
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = max(maxVal - minVal, 1)
            let stepX = geo.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, value) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat((value - minVal) / range))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight >= 1000 {
            return String(format: "%.0f lb", weight)
        }
        return String(format: "%.0f lb", weight.rounded())
    }
}
