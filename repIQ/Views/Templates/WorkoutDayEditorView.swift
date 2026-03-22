import SwiftUI

struct WorkoutDayEditorView: View {
    let day: WorkoutDay
    @Bindable var viewModel: TemplateEditorViewModel
    @State private var showExercisePicker = false
    @State private var selectedTrainingMode: TrainingMode = .hypertrophy
    @State private var supersetSource: WorkoutDayExercise?
    @State private var supersetSelections: Set<UUID> = []
    @State private var exerciseToDelete: WorkoutDayExercise?
    @State private var showDeleteConfirmation = false

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
                    HStack(spacing: RQSpacing.xs) {
                        Text("Exercises")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        MultiInfoButton(
                            topics: [
                                ProgressExplainer.trainingMode,
                                ProgressExplainer.targetSets,
                                ProgressExplainer.repRange,
                                ProgressExplainer.repCap,
                                ProgressExplainer.supersets,
                            ],
                            title: "Exercise Settings"
                        )
                    }
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
        .sheet(item: $supersetSource) { source in
            supersetPickerSheet(source: source)
        }
        .alert("Delete Exercise", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    Task {
                        await viewModel.removeExercise(exercise, from: currentDay)
                        exerciseToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove \(exerciseToDelete?.exercise?.name ?? "this exercise") from this workout day?")
        }
    }

    // MARK: - Superset Picker Sheet

    private func supersetPickerSheet(source: WorkoutDayExercise) -> some View {
        let exercises = currentDay.exercises?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
        let otherExercises = exercises.filter { $0.id != source.id }

        return NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Header explanation
                    VStack(spacing: RQSpacing.sm) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(RQColors.warning)

                        Text("Superset with \(source.exercise?.name ?? "Exercise")")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Select exercises to perform back-to-back with no rest between them.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, RQSpacing.md)

                    // Exercise selection list
                    VStack(spacing: RQSpacing.sm) {
                        ForEach(otherExercises) { exercise in
                            Button {
                                if supersetSelections.contains(exercise.id) {
                                    supersetSelections.remove(exercise.id)
                                } else {
                                    supersetSelections.insert(exercise.id)
                                }
                            } label: {
                                HStack(spacing: RQSpacing.md) {
                                    Image(systemName: supersetSelections.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(supersetSelections.contains(exercise.id) ? RQColors.warning : RQColors.textTertiary)

                                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                        Text(exercise.exercise?.name ?? "Unknown")
                                            .font(RQTypography.body)
                                            .foregroundColor(RQColors.textPrimary)

                                        if let ex = exercise.exercise {
                                            HStack(spacing: RQSpacing.sm) {
                                                Text(ex.muscleGroup.capitalized)
                                                    .font(RQTypography.caption)
                                                    .foregroundColor(RQColors.textTertiary)
                                                Text("\u{00B7}")
                                                    .foregroundColor(RQColors.textTertiary)
                                                Text(exercise.trainingMode.displayName)
                                                    .font(RQTypography.caption)
                                                    .foregroundColor(modeColor(exercise.trainingMode))
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(RQSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: RQRadius.medium)
                                        .fill(supersetSelections.contains(exercise.id) ? RQColors.warning.opacity(0.1) : RQColors.surfaceSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: RQRadius.medium)
                                        .stroke(supersetSelections.contains(exercise.id) ? RQColors.warning.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle("Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        supersetSource = nil
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(supersetSelections.isEmpty ? "Remove" : "Save") {
                        Task {
                            await viewModel.setSuperset(
                                source: source,
                                partners: supersetSelections,
                                in: currentDay
                            )
                            supersetSource = nil
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(supersetSelections.isEmpty ? RQColors.error : RQColors.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !supersetSelections.isEmpty {
                    supersetPreview(source: source)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(RQColors.background)
    }

    // Preview of what the superset will look like
    private func supersetPreview(source: WorkoutDayExercise) -> some View {
        let exercises = currentDay.exercises?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
        let selectedNames = [source.exercise?.name ?? "?"] + supersetSelections.compactMap { id in
            exercises.first(where: { $0.id == id })?.exercise?.name
        }

        return VStack(spacing: RQSpacing.xs) {
            Text("SUPERSET PREVIEW")
                .font(RQTypography.label)
                .tracking(1)
                .foregroundColor(RQColors.warning)

            Text(selectedNames.joined(separator: "  \u{2192}  "))
                .font(RQTypography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(RQColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(RQSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RQColors.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(RQColors.warning)
                .frame(height: 2),
            alignment: .top
        )
    }

    // MARK: - Exercise Card

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

                        // Superset button — next to exercise name
                        Button {
                            let exerciseCount = currentDay.exercises?.count ?? 0
                            if exerciseCount >= 2 {
                                openSupersetPicker(for: dayExercise)
                            }
                        } label: {
                            Image(systemName: dayExercise.supersetGroup != nil ? "link.circle.fill" : "link.circle")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    dayExercise.supersetGroup != nil
                                        ? RQColors.warning
                                        : (currentDay.exercises?.count ?? 0) >= 2
                                            ? RQColors.textPrimary
                                            : RQColors.textTertiary
                                )
                        }
                        .disabled((currentDay.exercises?.count ?? 0) < 2 && dayExercise.supersetGroup == nil)

                        Spacer()

                        // Delete button — spaced away from superset
                        Button {
                            exerciseToDelete = dayExercise
                            showDeleteConfirmation = true
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
                            Text("\u{00B7}")
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

                    // Rep range indicator (shows effective range when capped)
                    HStack {
                        Text("Rep Range")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        let effectiveRange = dayExercise.effectiveRepRange
                        Text("\(effectiveRange.lowerBound)-\(effectiveRange.upperBound) reps")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(modeColor(dayExercise.trainingMode))
                    }

                    // Rep cap control
                    HStack {
                        Text("Rep Cap")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        repCapControl(dayExercise)
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

    // MARK: - Helpers

    private func openSupersetPicker(for exercise: WorkoutDayExercise) {
        let exercises = currentDay.exercises?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []

        // Pre-select exercises already in the same superset group
        if let group = exercise.supersetGroup {
            supersetSelections = Set(
                exercises.filter { $0.supersetGroup == group && $0.id != exercise.id }.map(\.id)
            )
        } else {
            supersetSelections = []
        }

        supersetSource = exercise
    }

    private func supersetLabel(_ group: Int) -> String {
        let labels = ["A", "B", "C", "D", "E"]
        return labels[safe: group] ?? "\(group + 1)"
    }

    private func repCapControl(_ dayExercise: WorkoutDayExercise) -> some View {
        let range = dayExercise.trainingMode.repRange
        let hasCap = dayExercise.repCap != nil
        let currentCap = dayExercise.repCap ?? range.upperBound

        return HStack(spacing: RQSpacing.md) {
            if hasCap {
                Button {
                    let newCap = currentCap - 1
                    let repCap = newCap < range.lowerBound ? nil : newCap
                    Task {
                        await viewModel.updateExerciseMode(
                            dayExercise,
                            trainingMode: dayExercise.trainingMode,
                            targetSets: dayExercise.targetSets,
                            repCap: repCap
                        )
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(RQColors.textSecondary)
                }
            }

            Button {
                // Toggle: if off, set to upperBound - 1; if on, turn off
                let newCap: Int? = hasCap ? nil : max(range.lowerBound, range.upperBound - 1)
                Task {
                    await viewModel.updateExerciseMode(
                        dayExercise,
                        trainingMode: dayExercise.trainingMode,
                        targetSets: dayExercise.targetSets,
                        repCap: newCap
                    )
                }
            } label: {
                Text(hasCap ? "\(currentCap) reps" : "Off")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(hasCap ? modeColor(dayExercise.trainingMode) : RQColors.textTertiary)
                    .frame(minWidth: 50, alignment: .center)
            }

            if hasCap {
                Button {
                    let newCap = min(currentCap + 1, range.upperBound)
                    let repCap: Int? = newCap >= range.upperBound ? nil : newCap
                    Task {
                        await viewModel.updateExerciseMode(
                            dayExercise,
                            trainingMode: dayExercise.trainingMode,
                            targetSets: dayExercise.targetSets,
                            repCap: repCap
                        )
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private func trainingModeToggle(_ dayExercise: WorkoutDayExercise) -> some View {
        HStack(spacing: 0) {
            ForEach(TrainingMode.allCases, id: \.self) { mode in
                Button {
                    Task {
                        // Reset rep cap when changing mode (ranges differ)
                        await viewModel.updateExerciseMode(
                            dayExercise,
                            trainingMode: mode,
                            targetSets: dayExercise.targetSets,
                            repCap: nil
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
