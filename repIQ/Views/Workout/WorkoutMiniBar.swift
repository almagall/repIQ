import SwiftUI

/// Persistent mini-bar shown above the tab bar when an active workout is minimized.
/// Lets the user navigate the rest of the app while keeping essential workout state
/// glanceable: total elapsed time, current exercise + set progress, and the active
/// rest timer countdown. Tapping anywhere on the bar re-expands the full workout.
///
/// The killer feature is the rest timer in the right slot — users can navigate to
/// the social tab, check a friend's PR, look back at the bar and see "0:12 left"
/// without ever expanding the workout.
struct WorkoutMiniBar: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let onTap: () -> Void

    /// Pulse animation when the rest timer is in its final 5 seconds.
    @State private var pulse = false

    private var currentExercise: ExerciseLogEntry? {
        viewModel.currentExercise
    }

    private var setProgressLabel: String {
        guard let exercise = currentExercise else { return "" }
        let completedWorking = exercise.sets.filter { $0.isCompleted && $0.setType == .working }.count
        return "Set \(min(completedWorking + 1, exercise.targetSets))/\(exercise.targetSets)"
    }

    private var restTimerLabel: String {
        let total = viewModel.restTimerRemaining
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var restIsEndingSoon: Bool {
        viewModel.restTimerActive && viewModel.restTimerRemaining > 0 && viewModel.restTimerRemaining <= 5
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: RQSpacing.md) {
                // Left: elapsed time
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(RQColors.accent)
                    Text(viewModel.elapsedDisplay)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(RQColors.textPrimary)
                }
                .frame(width: 70, alignment: .leading)

                Divider()
                    .frame(height: 24)
                    .background(RQColors.surfaceTertiary)

                // Center: current exercise + set progress
                VStack(alignment: .leading, spacing: 1) {
                    if let exercise = currentExercise {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RQColors.textPrimary)
                            .lineLimit(1)
                        Text(setProgressLabel)
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.textTertiary)
                    } else {
                        Text("Workout in progress")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RQColors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: rest timer (when running) or chevron-up
                if viewModel.restTimerActive && viewModel.restTimerRemaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                        Text(restTimerLabel)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(restIsEndingSoon ? RQColors.warning : RQColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: RQRadius.small)
                            .fill((restIsEndingSoon ? RQColors.warning : RQColors.accent).opacity(0.15))
                    )
                    .scaleEffect(pulse && restIsEndingSoon ? 1.08 : 1.0)
                    .onChange(of: restIsEndingSoon) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                            pulse = newValue
                        }
                    }
                } else {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.xs)
            .frame(height: 56)
            .background(
                RQColors.surfaceSecondary
                    .overlay(
                        Rectangle()
                            .fill(RQColors.accent.opacity(0.4))
                            .frame(height: 1),
                        alignment: .top
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
