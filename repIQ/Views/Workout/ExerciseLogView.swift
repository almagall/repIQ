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

                    // Deload explanation banner
                    if let target = exercise.progressionTarget,
                       target.decision == .deload || target.decision == .deloadVolume {
                        deloadBanner(reasoning: target.reasoning)
                    }

                    Divider().background(RQColors.surfaceTertiary)

                    // Grouped set sections
                    ForEach(groupedSets, id: \.type) { group in
                        sectionHeader(for: group.type, count: group.sets.count)

                        // Column headers
                        columnHeaders

                        // Set rows
                        ForEach(Array(group.sets.enumerated()), id: \.element.entry.id) { groupIndex, item in
                            SwipeToDeleteWrapper {
                                SetRowView(
                                    viewModel: viewModel,
                                    exerciseIndex: exerciseIndex,
                                    setIndex: item.index,
                                    previousSet: previousSet(for: group.type, groupIndex: groupIndex),
                                    progressionTarget: group.type == .working ? exercise.progressionTarget : nil,
                                    setPosition: groupIndex
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                HStack(spacing: RQSpacing.sm) {
                    Text(exercise.exerciseName)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    // Inline superset indicator
                    if let group = exercise.supersetGroup {
                        let members = viewModel.supersetExercises(for: exerciseIndex)
                        let position = members.firstIndex(where: { $0.index == exerciseIndex }).map { $0 + 1 } ?? 1
                        Text("SS \(supersetLabel(group))·\(position)/\(members.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(RQColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RQColors.warning.opacity(0.15))
                            .cornerRadius(RQRadius.small)
                    }
                }

                HStack(spacing: RQSpacing.xs) {
                    Text(exercise.equipment.capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    Text("·")
                        .foregroundColor(RQColors.textTertiary)

                    Text(exercise.muscleGroup.capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    if exercise.isSubstituted {
                        Text("· Swapped")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent)
                    }
                }
            }

            Spacer()

            // Swap exercise button
            Button {
                viewModel.showExerciseSubstitution = true
            } label: {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RQColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(RQColors.surfaceTertiary)
                    .clipShape(Circle())
            }
        }
    }

    private func supersetLabel(_ group: Int) -> String {
        let labels = ["A", "B", "C", "D", "E"]
        return labels[safe: group] ?? "\(group + 1)"
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
        case .increaseReps: return RQColors.success
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
                .frame(width: 8)
            Text("REPS")
                .frame(width: 48, alignment: .center)
            Text("RPE")
            Spacer()
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
                    .font(.system(size: 14))
                Text("Add Set")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(RQColors.accent)
            .padding(.horizontal, RQSpacing.lg)
            .padding(.vertical, RQSpacing.sm)
            .background(RQColors.accent.opacity(0.1))
            .cornerRadius(RQRadius.medium)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Deload Banner

    private func deloadBanner(reasoning: String) -> some View {
        HStack(alignment: .top, spacing: RQSpacing.sm) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(RQColors.error)

            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                Text("Deload Active")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.error)

                Text(reasoning)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)

                Text("Deloads help you recover and break through plateaus. Trust the process.")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .italic()
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.error.opacity(0.08))
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Helpers

    private var modeColor: Color {
        exercise?.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
    }

    /// Returns the previous session's set data for a given set type and position within that group.
    /// Only working sets get ghost rows (previous session context is most useful there).
    private func previousSet(for type: SetType, groupIndex: Int) -> WorkoutSet? {
        guard type == .working, let exercise else { return nil }
        return exercise.previousSets.first?[safe: groupIndex]
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
