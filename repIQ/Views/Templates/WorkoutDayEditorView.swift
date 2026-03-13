import SwiftUI

struct WorkoutDayEditorView: View {
    let day: WorkoutDay
    @Bindable var viewModel: TemplateEditorViewModel
    @State private var showExercisePicker = false
    @State private var selectedTrainingMode: TrainingMode = .hypertrophy
    @State private var supersetToast: String?

    private var currentDay: WorkoutDay {
        viewModel.workoutDays.first(where: { $0.id == day.id }) ?? day
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Day Info Header
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text(currentDay.name)
                            .font(RQTypography.title2)
                            .foregroundColor(RQColors.textPrimary)
                        if let desc = currentDay.description, !desc.isEmpty {
                            Text(desc)
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                }

                // Exercises Header
                HStack {
                    Text("Exercises")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(RQTypography.subheadline)
                        .foregroundColor(RQColors.accent)
                    }
                }

                // Exercise List
                if let exercises = currentDay.exercises?.sorted(by: { $0.sortOrder < $1.sortOrder }), !exercises.isEmpty {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, dayExercise in
                        exerciseCard(dayExercise, index: index, total: exercises.count)
                    }
                } else {
                    RQCard {
                        VStack(spacing: RQSpacing.md) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 32))
                                .foregroundColor(RQColors.textTertiary)
                            Text("No exercises yet")
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                            Text("Add exercises to build this workout day.")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.lg)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle(currentDay.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if let toast = supersetToast {
                Text(toast)
                    .font(RQTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, RQSpacing.lg)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.warning.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, RQSpacing.xxxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: supersetToast)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                Task {
                    await viewModel.addExercise(
                        to: currentDay,
                        exercise: exercise,
                        trainingMode: selectedTrainingMode
                    )
                }
            }
        }
    }

    private func exerciseCard(_ dayExercise: WorkoutDayExercise, index: Int, total: Int) -> some View {
        let allExercises = currentDay.exercises?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []

        return VStack(spacing: 0) {
            // Superset bracket indicator (if part of a superset)
            if let group = dayExercise.supersetGroup {
                let isFirstInGroup = index == 0 || allExercises[safe: index - 1]?.supersetGroup != group
                if isFirstInGroup {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .bold))
                        Text("SUPERSET \(supersetLabel(group))")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1)
                    }
                    .foregroundColor(RQColors.warning)
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, RQSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    // Exercise name, reorder, and remove
                    HStack(spacing: RQSpacing.sm) {
                        // Reorder buttons
                        VStack(spacing: 2) {
                            Button {
                                Task {
                                    await viewModel.moveExercise(in: currentDay, from: index, to: index - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(index > 0 ? RQColors.textSecondary : RQColors.surfaceTertiary)
                            }
                            .disabled(index == 0)

                            Button {
                                Task {
                                    await viewModel.moveExercise(in: currentDay, from: index, to: index + 1)
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(index < total - 1 ? RQColors.textSecondary : RQColors.surfaceTertiary)
                            }
                            .disabled(index == total - 1)
                        }
                        .frame(width: 24)

                        Text(dayExercise.exercise?.name ?? "Unknown Exercise")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)

                        Spacer()

                        // Superset toggle button (only show if not last exercise)
                        if index < total - 1 {
                            Button {
                                let wasInSuperset = dayExercise.supersetGroup != nil
                                let nextName = allExercises[safe: index + 1]?.exercise?.name ?? "next exercise"
                                let currentName = dayExercise.exercise?.name ?? "exercise"
                                Task {
                                    await viewModel.toggleSuperset(for: dayExercise, in: currentDay)
                                    await MainActor.run {
                                        if wasInSuperset {
                                            supersetToast = "Superset removed"
                                        } else {
                                            supersetToast = "\(currentName) + \(nextName) linked as superset"
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            withAnimation { supersetToast = nil }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: dayExercise.supersetGroup != nil ? "link.circle.fill" : "link.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(dayExercise.supersetGroup != nil ? RQColors.warning : RQColors.textTertiary)
                            }
                        }

                        Button {
                            Task {
                                await viewModel.removeExercise(dayExercise, from: currentDay)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(RQColors.error)
                        }
                    }

                    // Equipment + Muscle info
                    if let exercise = dayExercise.exercise {
                        HStack(spacing: RQSpacing.sm) {
                            Text(exercise.muscleGroup.capitalized)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                            Text("·")
                                .foregroundColor(RQColors.textTertiary)
                            Text(exercise.equipment.capitalized)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }

                    Divider().background(RQColors.surfaceTertiary)

                    // Training mode toggle
                    HStack {
                        Text("Mode")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        trainingModeToggle(dayExercise)
                    }

                    // Target sets
                    HStack {
                        Text("Target Sets")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        HStack(spacing: RQSpacing.md) {
                            Button {
                                let newSets = max(1, dayExercise.targetSets - 1)
                                Task {
                                    await viewModel.updateExerciseMode(
                                        dayExercise,
                                        trainingMode: dayExercise.trainingMode,
                                        targetSets: newSets
                                    )
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(RQColors.textSecondary)
                            }
                            Text("\(dayExercise.targetSets)")
                                .font(RQTypography.numbersSmall)
                                .foregroundColor(RQColors.textPrimary)
                                .frame(width: 24, alignment: .center)
                            Button {
                                let newSets = min(10, dayExercise.targetSets + 1)
                                Task {
                                    await viewModel.updateExerciseMode(
                                        dayExercise,
                                        trainingMode: dayExercise.trainingMode,
                                        targetSets: newSets
                                    )
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(RQColors.textSecondary)
                            }
                        }
                    }

                    // Rep range indicator
                    HStack {
                        Text("Rep Range")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        let range = dayExercise.trainingMode.repRange
                        Text("\(range.lowerBound)-\(range.upperBound) reps")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(modeColor(dayExercise.trainingMode))
                    }
                }
            }
            .overlay(
                // Left accent bar for superset members
                dayExercise.supersetGroup != nil
                    ? RoundedRectangle(cornerRadius: 2)
                        .fill(RQColors.warning)
                        .frame(width: 3)
                        .padding(.vertical, RQSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    : nil
            )
        }
    }

    private func supersetLabel(_ group: Int) -> String {
        let labels = ["A", "B", "C", "D", "E"]
        return labels[safe: group] ?? "\(group + 1)"
    }

    private func trainingModeToggle(_ dayExercise: WorkoutDayExercise) -> some View {
        HStack(spacing: 0) {
            ForEach(TrainingMode.allCases, id: \.self) { mode in
                Button {
                    Task {
                        await viewModel.updateExerciseMode(
                            dayExercise,
                            trainingMode: mode,
                            targetSets: dayExercise.targetSets
                        )
                    }
                } label: {
                    Text(mode.displayName)
                        .font(RQTypography.caption)
                        .foregroundColor(dayExercise.trainingMode == mode ? RQColors.background : RQColors.textSecondary)
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, RQSpacing.sm)
                        .background(dayExercise.trainingMode == mode ? modeColor(mode) : RQColors.surfaceTertiary)
                }
            }
        }
        .cornerRadius(RQRadius.small)
    }

    private func modeColor(_ mode: TrainingMode) -> Color {
        switch mode {
        case .hypertrophy: return RQColors.hypertrophy
        case .strength: return RQColors.strength
        }
    }
}
