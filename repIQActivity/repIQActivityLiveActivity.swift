import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for an in-progress workout. Renders three contexts:
/// - Lock Screen / Notification Center (full layout)
/// - Dynamic Island compact (collapsed, only icon + small status)
/// - Dynamic Island expanded (4 regions when long-pressed)
/// - Dynamic Island minimal (single icon when other activities compete)
///
/// Live counters use `Text(timerInterval:)` so they auto-update on the device
/// without push updates. The main app only pushes ContentState changes on
/// meaningful events (set logged, exercise changed, rest started/ended).
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
                    HStack {
                        Text(context.attributes.workoutName)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                        Spacer()
                        if context.state.isRestActive {
                            Text(context.state.setProgress)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
            } compactLeading: {
                // MARK: - Dynamic Island Compact (left)
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(accent)
            } compactTrailing: {
                // MARK: - Dynamic Island Compact (right)
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
                // MARK: - Dynamic Island Minimal (single glyph)
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(accent)
            }
            .keylineTint(accent)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: workout name + elapsed time
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                Text(context.attributes.workoutName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer()
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture,
                     countsDown: false,
                     showsHours: false)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, alignment: .trailing)
            }

            // Middle row: current exercise + set progress
            HStack(alignment: .firstTextBaseline) {
                Text(context.state.currentExerciseName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(context.state.setProgress)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.white.opacity(0.12))
                    )
            }

            // Bottom row: rest timer or "Ready for next set"
            if let restEndDate = context.state.restEndDate, context.state.isRestActive {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accent)
                    Text("Rest")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text(timerInterval: Date()...restEndDate, countsDown: true, showsHours: false)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                        .monospacedDigit()
                }
                .padding(.top, 2)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Ready for your next set")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
