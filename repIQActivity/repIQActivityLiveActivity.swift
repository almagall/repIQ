import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

/// Live Activity widget for an in-progress workout. Renders three contexts:
/// - Lock Screen / Notification Center (full layout)
/// - Dynamic Island compact (collapsed, only icon + small status)
/// - Dynamic Island expanded (4 regions when long-pressed)
/// - Dynamic Island minimal (single icon when other activities compete)
///
/// Live counters use `Text(timerInterval:)` so they auto-update on the device
/// without push updates. The main app pushes ContentState changes on
/// meaningful events (set logged, exercise changed, rest started/ended,
/// stepper tapped).
struct repIQActivityLiveActivity: Widget {
    private let accent = Color(red: 0.0, green: 0.85, blue: 1.0) // matches RQColors.accent

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // MARK: - Lock Screen / Notification Center
            lockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Dynamic Island Expanded (4 regions)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(accent)
                        Text(timerInterval: context.attributes.startedAt...Date.distantFuture,
                             countsDown: false,
                             showsHours: false)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 50, alignment: .leading)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let restEndDate = context.state.restEndDate, context.state.isRestActive {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .bold))
                            Text(timerInterval: Date()...restEndDate,
                                 countsDown: true,
                                 showsHours: false)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 50, alignment: .trailing)
                        }
                        .foregroundColor(accent)
                    } else {
                        Text(context.state.setProgress)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentExerciseName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(accent)
            } compactTrailing: {
                if let restEndDate = context.state.restEndDate, context.state.isRestActive {
                    Text(timerInterval: Date()...restEndDate, countsDown: true, showsHours: false)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                        .frame(width: 42, alignment: .trailing)
                        .monospacedDigit()
                } else {
                    Text(context.state.setProgress.replacingOccurrences(of: "Set ", with: ""))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(accent)
            }
            .keylineTint(accent)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        let s = context.state
        VStack(alignment: .leading, spacing: 8) {
            // Header — no Text(timerInterval:) here; it was a likely culprit
            // for starving sibling views during layout. Elapsed time can
            // come back later via simple computed text.
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                Text(s.currentExerciseName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(s.setProgress.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(accent)
            }

            if s.isRestActive, let restEndDate = s.restEndDate {
                restRow(restEndDate: restEndDate)
            } else if s.setKind == .working {
                workingSetView(state: s)
            } else if s.setKind == .warmup {
                placeholderRow(text: "Open repIQ to log warmup", icon: "flame.fill")
            } else {
                placeholderRow(text: "Ready for your next set", icon: "checkmark.circle.fill")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }


    @ViewBuilder
    private func restRow(restEndDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                Text("Rest")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(timerInterval: Date()...restEndDate, countsDown: true, showsHours: false)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
                    .monospacedDigit()
            }
            Button(intent: SkipRestIntent()) {
                Text("Skip rest")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func workingSetView(state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 3-column horizontal stepper block. One row of vertical
            // controls instead of three saves ~50pt — critical because
            // iOS clips Lock Screen activities above ~135pt.
            HStack(spacing: 10) {
                if let weight = state.pendingWeight {
                    stepperColumn(
                        label: "WEIGHT",
                        value: "\(formatWeight(weight)) \(state.weightUnit)",
                        field: .weight
                    )
                }
                stepperColumn(
                    label: "REPS",
                    value: "\(state.pendingReps)",
                    field: .reps
                )
                stepperColumn(
                    label: "RPE",
                    value: state.pendingRPE.map { formatRPE($0) } ?? "—",
                    field: .rpe
                )
            }

            // Bottom row: Goal + Last context stacked on the left, LOG
            // button on the right. Both vertically aligned so the row fits
            // in ~26pt total.
            HStack(alignment: .center, spacing: 10) {
                contextStack(state: state)
                Spacer(minLength: 8)
                Button(intent: LogSetIntent()) {
                    Text("LOG SET")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(Color.black)
                .controlSize(.small)
            }
        }
    }

    /// Single column in the 3-column stepper block: small uppercase label,
    /// bold value, and a `[−] [+]` cluster centered below.
    @ViewBuilder
    private func stepperColumn(label: String, value: String, field: SetField) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Button(intent: AdjustSetIntent(field: field, direction: .down)) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .controlSize(.mini)

                Button(intent: AdjustSetIntent(field: field, direction: .up)) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .controlSize(.mini)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Goal + Last as a tight two-line block on the left of the bottom row.
    /// Goal is accent-tinted, Last is muted.
    @ViewBuilder
    private func contextStack(state: WorkoutActivityAttributes.ContentState) -> some View {
        let goal = formatGoal(state: state)
        let last = state.previousSet.map { formatPrevious($0, unit: state.weightUnit) }

        VStack(alignment: .leading, spacing: 1) {
            if let goal {
                HStack(spacing: 4) {
                    Text("GOAL")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.6)
                        .foregroundColor(accent.opacity(0.85))
                    Text(goal)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accent)
                        .lineLimit(1)
                }
            }
            if let last {
                HStack(spacing: 4) {
                    Text("LAST")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.6)
                        .foregroundColor(.white.opacity(0.4))
                    Text(last)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private func placeholderRow(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.45))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Dynamic Island Expanded Bottom

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        let state = context.state
        if state.isRestActive {
            HStack {
                Text(context.attributes.workoutName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer()
                Button(intent: SkipRestIntent()) {
                    Text("Skip rest")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .controlSize(.small)
            }
        } else if state.setKind == .working {
            workingSetView(state: state)
        } else {
            HStack {
                Text(context.attributes.workoutName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer()
                Text(state.setProgress)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Formatters

    private func formatGoal(state: WorkoutActivityAttributes.ContentState) -> String? {
        guard state.goalReps > 0 else { return nil }
        var s = ""
        if let w = state.goalWeight, w > 0 {
            s = "\(formatWeight(w)) \(state.weightUnit) × \(state.goalReps)"
        } else {
            s = "\(state.goalReps) reps"
        }
        if let rpe = state.goalRPE {
            s += " @ \(formatRPE(rpe))"
        }
        return s
    }

    private func formatPrevious(_ prev: WorkoutActivityAttributes.PreviousSetSummary, unit: String) -> String {
        var s = ""
        if let w = prev.weight, w > 0 {
            s = "\(formatWeight(w)) \(unit) × \(prev.reps)"
        } else {
            s = "\(prev.reps) reps"
        }
        if let rpe = prev.rpe {
            s += " @ \(formatRPE(rpe))"
        }
        return s
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatRPE(_ rpe: Double) -> String {
        rpe.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rpe)
            : String(format: "%.1f", rpe)
    }
}
