import SwiftUI

struct ExerciseLogView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int

    private var exercise: ExerciseLogEntry? {
        viewModel.exercises[safe: exerciseIndex]
    }

    var body: some View {
        guard let exercise else { return AnyView(EmptyView()) }

        return AnyView(
            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    // Exercise Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(exercise.exerciseName)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)

                            HStack(spacing: RQSpacing.sm) {
                                Text(exercise.equipment.capitalized)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)

                                Text("·")
                                    .foregroundColor(RQColors.textTertiary)

                                Text(exercise.muscleGroup.capitalized)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }

                        Spacer()

                        // Training mode badge
                        Text(exercise.trainingMode.displayName)
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(modeColor)
                            .padding(.horizontal, RQSpacing.sm)
                            .padding(.vertical, RQSpacing.xs)
                            .background(modeColor.opacity(0.15))
                            .cornerRadius(RQRadius.small)
                    }

                    // Progress indicator
                    HStack(spacing: RQSpacing.sm) {
                        Text("\(exercise.completedSetCount)/\(exercise.targetSets) sets")
                            .font(RQTypography.caption)
                            .foregroundColor(
                                exercise.isAllSetsCompleted
                                    ? RQColors.success
                                    : RQColors.textSecondary
                            )

                        if exercise.isAllSetsCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(RQColors.success)
                        }

                        Spacer()

                        let range = exercise.trainingMode.repRange
                        Text("\(range.lowerBound)-\(range.upperBound) reps")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        Text("RPE \(formatRPE(exercise.trainingMode.targetRPE))")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Divider().background(RQColors.surfaceTertiary)

                    // Previous session data
                    PreviousSetsView(
                        previousSets: exercise.previousSets,
                        isExpanded: exercise.isExpanded,
                        onToggle: { viewModel.togglePreviousSets(exerciseIndex: exerciseIndex) }
                    )

                    // Column headers
                    HStack(spacing: RQSpacing.sm) {
                        Text("SET")
                            .frame(width: 26, alignment: .center)
                        Text("")
                            .frame(width: 24)
                        Text("LBS")
                            .frame(width: 64, alignment: .center)
                        Text("")
                            .frame(width: 10) // × spacer
                        Text("REPS")
                            .frame(width: 48, alignment: .center)
                        Text("RPE")
                        Spacer()
                        Text("")
                            .frame(width: 32) // checkmark spacer
                    }
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)

                    // Set rows
                    ForEach(exercise.sets.indices, id: \.self) { setIndex in
                        SetRowView(
                            viewModel: viewModel,
                            exerciseIndex: exerciseIndex,
                            setIndex: setIndex
                        )
                    }

                    // Add Set button
                    Button {
                        viewModel.addSet(exerciseIndex: exerciseIndex)
                    } label: {
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                            Text("Add Set")
                                .font(RQTypography.subheadline)
                        }
                        .foregroundColor(RQColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                    }
                }
            }
        )
    }

    private var modeColor: Color {
        exercise?.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
