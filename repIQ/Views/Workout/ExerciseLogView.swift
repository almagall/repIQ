import SwiftUI

struct ExerciseLogView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int

    @State private var setToDelete: Int?
    @State private var showDeleteConfirmation = false

    private var exercise: ExerciseLogEntry? {
        viewModel.exercises[safe: exerciseIndex]
    }

    /// Sets grouped by type in display order, with their original indices.
    private var groupedSets: [(type: SetType, sets: [(index: Int, entry: SetEntry)])] {
        guard let exercise else { return [] }

        var groups: [SetType: [(index: Int, entry: SetEntry)]] = [:]
        for (index, set) in exercise.sets.enumerated() {
            groups[set.setType, default: []].append((index: index, entry: set))
        }

        // Sort groups by type display order
        let orderedTypes: [SetType] = [.warmup, .working, .drop, .failure, .cooldown]
        return orderedTypes.compactMap { type in
            guard let sets = groups[type], !sets.isEmpty else { return nil }
            return (type: type, sets: sets)
        }
    }

    var body: some View {
        guard let exercise else { return AnyView(EmptyView()) }

        return AnyView(
            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    // Exercise Header
                    exerciseHeader(exercise)

                    // Progress indicator
                    progressRow(exercise)

                    Divider().background(RQColors.surfaceTertiary)

                    // Previous session data
                    PreviousSetsView(
                        previousSets: exercise.previousSets,
                        isExpanded: exercise.isExpanded,
                        onToggle: { viewModel.togglePreviousSets(exerciseIndex: exerciseIndex) }
                    )

                    // Grouped set sections
                    ForEach(groupedSets, id: \.type) { group in
                        sectionHeader(for: group.type, count: group.sets.count)

                        // Column headers
                        columnHeaders

                        // Set rows
                        ForEach(group.sets, id: \.entry.id) { item in
                            SwipeToDeleteWrapper {
                                SetRowView(
                                    viewModel: viewModel,
                                    exerciseIndex: exerciseIndex,
                                    setIndex: item.index
                                )
                            } onDelete: {
                                setToDelete = item.index
                                showDeleteConfirmation = true
                            }
                        }
                    }

                    // Add Set menu
                    addSetMenu
                }
            }
            .alert("Delete Set?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let index = setToDelete {
                        Task { await viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: index) }
                    }
                    setToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    setToDelete = nil
                }
            } message: {
                if let index = setToDelete,
                   let set = exercise.sets[safe: index] {
                    if set.isCompleted {
                        Text("This set has been logged. Deleting it will remove it from your workout record.")
                    } else {
                        Text("Are you sure you want to remove this set?")
                    }
                } else {
                    Text("Are you sure you want to remove this set?")
                }
            }
        )
    }

    // MARK: - Exercise Header

    private func exerciseHeader(_ exercise: ExerciseLogEntry) -> some View {
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
    }

    // MARK: - Progress Row

    private func progressRow(_ exercise: ExerciseLogEntry) -> some View {
        VStack(spacing: RQSpacing.sm) {
            // Target row (if progression target exists)
            if let target = exercise.progressionTarget {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: decisionIcon(target.decision))
                        .font(.system(size: 11))
                        .foregroundColor(decisionColor(target.decision))

                    Text(target.decision.displayName)
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(decisionColor(target.decision))

                    Text("·")
                        .foregroundColor(RQColors.textTertiary)

                    Text("\(formatWeight(target.targetWeight)) lbs × \(target.targetRepRangeDisplay)")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    Text("RPE \(formatRPE(target.targetRPE))")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            // Set count + rep range
            HStack(spacing: RQSpacing.sm) {
                let workingSets = exercise.sets.filter { $0.setType == .working }
                let completedWorking = workingSets.filter(\.isCompleted).count
                Text("\(completedWorking)/\(exercise.targetSets) working sets")
                    .font(RQTypography.caption)
                    .foregroundColor(
                        completedWorking >= exercise.targetSets
                            ? RQColors.success
                            : RQColors.textSecondary
                    )

                if completedWorking >= exercise.targetSets {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.success)
                }

                Spacer()

                if exercise.progressionTarget == nil {
                    let range = exercise.trainingMode.repRange
                    Text("\(range.lowerBound)-\(range.upperBound) reps")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    Text("RPE \(formatRPE(exercise.trainingMode.targetRPE))")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Decision Helpers

    private func decisionIcon(_ decision: ProgressionDecision) -> String {
        switch decision {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .increaseReps: return "arrow.up.right.circle.fill"
        case .maintain: return "arrow.right.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .deloadVolume: return "arrow.down.circle.fill"
        }
    }

    private func decisionColor(_ decision: ProgressionDecision) -> Color {
        switch decision {
        case .increaseWeight: return RQColors.success
        case .increaseReps: return RQColors.accent
        case .maintain: return RQColors.warning
        case .deload: return RQColors.error
        case .deloadVolume: return RQColors.error
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    // MARK: - Section Header

    private func sectionHeader(for type: SetType, count: Int) -> some View {
        HStack(spacing: RQSpacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(colorForSetType(type))
                .frame(width: 3, height: 14)

            Image(systemName: type.icon)
                .font(.system(size: 11))
                .foregroundColor(colorForSetType(type))

            Text(type.displayName)
                .font(RQTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(colorForSetType(type))

            Text("(\(count))")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)

            Spacer()
        }
        .padding(.top, RQSpacing.sm)
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: RQSpacing.sm) {
            Text("SET")
                .frame(width: 26, alignment: .center)
            Text("LBS")
                .frame(width: 64, alignment: .center)
            Text("")
                .frame(width: 10)
            Text("REPS")
                .frame(width: 48, alignment: .center)
            Text("RPE")
            Spacer()
            Text("")
                .frame(width: 28) // checkmark spacer
        }
        .font(RQTypography.caption)
        .foregroundColor(RQColors.textTertiary)
    }

    // MARK: - Add Set Menu

    private var addSetMenu: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    viewModel.addSet(exerciseIndex: exerciseIndex, setType: type)
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
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

    // MARK: - Helpers

    private var modeColor: Color {
        exercise?.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
    }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .warmup: return RQColors.warmup
        case .working: return RQColors.working
        case .cooldown: return RQColors.cooldown
        case .drop: return RQColors.dropSet
        case .failure: return RQColors.failure
        }
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
