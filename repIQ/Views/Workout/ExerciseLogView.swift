import SwiftUI

struct ExerciseLogView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int

    @State private var setToDelete: Int?
    @State private var showDeleteConfirmation = false
    @State private var showDecisionInfoSheet = false

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
                        // Warmup suggestion and/or add button before working sets
                        if group.type == .working {
                            if viewModel.shouldSuggestWarmup(exerciseIndex: exerciseIndex) {
                                warmupSuggestionCard
                            }
                            addWarmUpButton
                        }

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

                // Add Weight toggle for bodyweight exercises
                if exercise.equipment == "bodyweight" {
                    Button {
                        viewModel.toggleAddedWeight(exerciseIndex: exerciseIndex)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: exercise.useAddedWeight ? "minus.circle" : "plus.circle")
                                .font(.system(size: 11))
                            Text(exercise.useAddedWeight ? "Remove Weight" : "Add Weight")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(RQColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RQColors.accent.opacity(0.1))
                        .cornerRadius(RQRadius.small)
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

            // Superset menu (chain icon, matches template editor)
            Menu {
                if exercise.supersetGroup != nil {
                    Button(role: .destructive) {
                        viewModel.removeFromAdHocSuperset(exerciseIndex: exerciseIndex)
                    } label: {
                        Label("Remove from Superset", systemImage: "link.badge.minus")
                    }
                } else {
                    let available = viewModel.availableExercisesForSuperset(excluding: exerciseIndex)
                    if !available.isEmpty {
                        ForEach(available, id: \.index) { item in
                            Button(item.name) {
                                viewModel.createAdHocSuperset(exerciseIndex: exerciseIndex, withExerciseIndex: item.index)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: exercise.supersetGroup != nil ? "link.circle.fill" : "link.circle")
                    .font(.system(size: 18))
                    .foregroundColor(exercise.supersetGroup != nil ? RQColors.supersetGold : RQColors.textSecondary)
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

                    Button {
                        showDecisionInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(RQColors.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Text("·")
                        .foregroundColor(RQColors.textTertiary)

                    Text("\(formatWeight(target.targetWeight)) lbs × \(target.targetRepRangeDisplay)")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    // RPE range for hypertrophy, ascending range for strength
                    if exercise.trainingMode == .hypertrophy {
                        let baseRPE = target.targetRPE
                        let topRPE = min(baseRPE + Double(exercise.targetSets - 1) * 0.5, 9.0)
                        Text("RPE \(formatRPE(baseRPE))–\(formatRPE(topRPE))")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    } else {
                        Text("RPE 6–\(formatRPE(target.targetRPE))")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
                .sheet(isPresented: $showDecisionInfoSheet) {
                    InfoSheet(topic: decisionTopic(target))
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

    private func decisionTopic(_ target: ProgressionTarget) -> ProgressExplainer.Topic {
        let (title, icon, explanation, keyPoints, howToUse): (String, String, String, [String], String)

        switch target.decision {
        case .increaseWeight:
            title = "Increase Weight"
            icon = "arrow.up.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Your estimated 1RM is trending upward across recent sessions.",
                "Weight is prescribed as a percentage of your current e1RM for your target rep range.",
                "After increasing weight, your reps will reset to the bottom of the range — this is normal.",
            ]
            howToUse = "Focus on hitting the target weight for the prescribed reps on each set. If you can't complete the minimum reps, the weight may auto-adjust next session."

        case .increaseReps:
            title = "Increase Reps"
            icon = "arrow.up.right.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Your strength is stable — estimated 1RM hasn't changed significantly.",
                "Adding reps at the same weight is how you earn the next weight increase.",
                "Once you hit the top of your rep range on all sets, weight will go up.",
            ]
            howToUse = "Keep the same weight and aim for 1-2 more reps than last session. When you consistently hit the top of your rep range, the algorithm will prescribe a weight increase."

        case .maintain:
            title = "Maintain"
            icon = "arrow.right.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "This is not a setback — maintaining is part of the progression cycle.",
                "Your body may need time to adapt before the next jump.",
                "Repeating the same performance builds the capacity for future progress.",
            ]
            howToUse = "Match what you did last session. Focus on form and controlled reps. Consistent effort at the same load builds the foundation for your next progression."

        case .deload:
            title = "Deload"
            icon = "arrow.down.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Your estimated 1RM has been declining — a sign of accumulated fatigue.",
                "Reducing weight temporarily allows your body to recover and rebuild.",
                "Deloads are a proven strategy for breaking through plateaus.",
            ]
            howToUse = "Use the reduced weight this session. Focus on crisp, controlled reps. You should feel strong again within 1-2 sessions, at which point the algorithm will push you forward."

        case .deloadVolume:
            title = "Reduce Volume"
            icon = "arrow.down.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Reducing the number of sets helps manage fatigue while keeping intensity high.",
                "This is typically suggested after extended periods of high-volume training.",
                "Your weight targets remain the same — just fewer sets.",
            ]
            howToUse = "Complete the prescribed sets at full effort. The reduced volume gives your body a chance to recover without losing strength."
        }

        return ProgressExplainer.Topic(
            title: title,
            icon: icon,
            explanation: explanation,
            keyPoints: keyPoints,
            howToUse: howToUse
        )
    }

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
        let isBodyweight = exercise?.isBodyweightOnly ?? false
        return HStack(spacing: RQSpacing.sm) {
            Text("SET")
                .frame(width: 26, alignment: .center)
            Text(isBodyweight ? "BW" : "LBS")
                .frame(width: 64, alignment: .center)
            Text("")
                .frame(width: 8)
            Text("REPS")
                .frame(width: 48, alignment: .center)
            Text("")
                .frame(width: 8)
            Text("RPE")
                .frame(width: 56, alignment: .center)
            Spacer()
        }
        .font(RQTypography.caption)
        .foregroundColor(RQColors.textTertiary)
    }

    // MARK: - Add Set Menu

    private var warmupSuggestionCard: some View {
        let weights = viewModel.suggestedWarmupWeights(exerciseIndex: exerciseIndex)

        return VStack(spacing: 0) {
            HStack {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.warmup)

                    Text("Suggested Warm-Up")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.addSuggestedWarmups(exerciseIndex: exerciseIndex)
                    }
                } label: {
                    Text("Add")
                        .font(RQTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(RQColors.background)
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, 5)
                        .background(RQColors.warmup)
                        .cornerRadius(RQRadius.medium)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.dismissWarmupSuggestion(exerciseIndex: exerciseIndex)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }
            }

            if let weights {
                HStack(spacing: RQSpacing.lg) {
                    HStack(spacing: RQSpacing.xs) {
                        Text("W1")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.warmup)
                        Text("\(formatWeight(weights.warmup1)) × 10")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    HStack(spacing: RQSpacing.xs) {
                        Text("W2")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.warmup)
                        Text("\(formatWeight(weights.warmup2)) × 5")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
                .padding(.top, RQSpacing.sm)
            }
        }
        .padding(RQSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .strokeBorder(RQColors.warmup.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .background(RQColors.warmup.opacity(0.05).cornerRadius(RQRadius.medium))
        )
        .padding(.top, RQSpacing.sm)
    }

    private var addWarmUpButton: some View {
        Button {
            viewModel.dismissWarmupSuggestion(exerciseIndex: exerciseIndex)
            viewModel.addSet(exerciseIndex: exerciseIndex, setType: .warmup)
        } label: {
            HStack(spacing: RQSpacing.xs) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                Text("Add Warm Up")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(RQColors.warmup)
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, 6)
            .background(RQColors.warmup.opacity(0.1))
            .cornerRadius(RQRadius.medium)
        }
        .padding(.top, RQSpacing.xs)
    }

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
