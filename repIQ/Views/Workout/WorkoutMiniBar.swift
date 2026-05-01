import SwiftUI

/// Persistent mini-bar shown above the tab bar when an active workout is minimized.
/// Renders as a self-contained capsule with its own background, drawn manually
/// in MainTabView's ZStack overlay (NOT inside `tabViewBottomAccessory`, which
/// has rendering quirks on iOS 26).
struct WorkoutMiniBar: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let onTap: () -> Void

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

    private var restIsActive: Bool {
        viewModel.restTimerActive && viewModel.restTimerRemaining > 0
    }

    private var restIsEndingSoon: Bool {
        restIsActive && viewModel.restTimerRemaining <= 5
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(RQColors.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentExercise?.exerciseName ?? "Workout in progress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)
                    if !setProgressLabel.isEmpty {
                        Text("\(setProgressLabel) · \(viewModel.elapsedDisplay)")
                            .font(.system(size: 11))
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text(viewModel.elapsedDisplay)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Spacer(minLength: 4)

                if restIsActive {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                        Text(restTimerLabel)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundColor(restIsEndingSoon ? RQColors.warning : RQColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((restIsEndingSoon ? RQColors.warning : RQColors.accent).opacity(0.15))
                    )
                } else {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(RQColors.surfaceSecondary)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(RQColors.accent.opacity(0.25), lineWidth: 1)
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
