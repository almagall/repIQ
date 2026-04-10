import SwiftUI

/// The hero card at the top of the Progress tab showing the user's top
/// most-logged lifts scoped by workout day, with current estimated 1RM,
/// 4-week delta, velocity status, a tiny sparkline, and a coaching narrative.
struct StrengthTrajectoryCard: View {
    let lifts: [TopLiftTrajectory]
    var onSelect: ((TopLiftTrajectory) -> Void)? = nil
    var onBrowseAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("STRENGTH TRAJECTORY")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
            }

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
                }

                Spacer(minLength: RQSpacing.sm)

                // Middle: sparkline
                if lift.sparkline.count >= 2 {
                    sparkline(lift.sparkline, color: lift.velocityStatus.color)
                        .frame(width: 48, height: 24)
                }

                // Right: e1RM + delta
                VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
