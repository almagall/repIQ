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

                    // First-time tooltip: targets
                    if exercise.progressionTarget != nil {
                        FirstTimeTooltip(
                            key: "workout_targets",
                            icon: "target",
                            message: "These are your personalized targets based on past performance. Aim for the target weight and reps, but adjust if something feels off. The app learns from every session."
                        )
                    }

                    // Deload explanation banner
                    if let target = exercise.progressionTarget,
                       target.decision == .deload || target.decision == .deloadVolume {
                        deloadBanner(reasoning: target.reasoning)
                    }

                    // First-time exercise baseline banner
                    if exercise.progressionTarget == nil {
                        baselineBanner(exercise)
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

                        // First-time RPE tooltip (only on working sets)
                        if group.type == .working {
                            FirstTimeTooltip(
                                key: "workout_rpe",
                                icon: "gauge.with.needle.fill",
                                message: "RPE measures how hard a set felt (7 = moderate, 8 = challenging, 9 = very hard). Tap after completing a set. This is optional but helps the app calibrate your targets."
                            )
                        }

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
                    // Training mode badge
                    Text(exercise.trainingMode.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(modeColorFor(exercise.trainingMode))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColorFor(exercise.trainingMode).opacity(0.15))
                        .cornerRadius(RQRadius.small)

                    Text(exercise.repRangeDisplay + " reps")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(modeColorFor(exercise.trainingMode))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColorFor(exercise.trainingMode).opacity(0.1))
                        .cornerRadius(RQRadius.small)

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
                if exercise.isBodyweightOnly || exercise.useAddedWeight {
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
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: decisionIcon(target.decision))
                            .font(.system(size: 10, weight: .bold))

                        Text(target.decision.displayName.uppercased())
                            .rqLabel()

                        Button {
                            showDecisionInfoSheet = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(decisionColor(target.decision))

                    HStack(alignment: .bottom, spacing: RQSpacing.md) {
                        prescriptionFigure(exercise, target)

                        Spacer(minLength: RQSpacing.sm)

                        // No LAST here on purpose: the context strip on the live
                        // set already shows it, sourced from the actual set at
                        // that position rather than the engine's stored summary.
                        // Both on screen would visibly disagree.
                        prescriptionStat("TARGET RPE", targetRPEDisplay(exercise, target))
                    }
                }
                .sheet(isPresented: $showDecisionInfoSheet) {
                    InfoSheet(topic: decisionTopic(target))
                }

                // Inline reasoning — visible for non-deload decisions that carry
                // it. Legacy rows have theirs cleared by clampedTarget, so the
                // emptiness check keeps the icon from rendering on its own.
                if target.decision != .deload && target.decision != .deloadVolume,
                   !target.reasoning.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        HStack(alignment: .top, spacing: RQSpacing.xs) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.textTertiary)
                                .padding(.top, 1)

                            Text(target.reasoning)
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Signal indicators
                        HStack(spacing: RQSpacing.md) {
                            if target.rpeFatigueDetected {
                                HStack(spacing: RQSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(RQColors.warning.opacity(0.8))
                                    Text("RPE fatigue signal")
                                        .font(.system(size: 10))
                                        .foregroundColor(RQColors.warning.opacity(0.8))
                                }
                            }

                            if target.mesocycleRPEOffset > 0 {
                                HStack(spacing: RQSpacing.xs) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 9))
                                        .foregroundColor(RQColors.accent.opacity(0.6))
                                    Text("Mesocycle RPE +\(formatRPE(target.mesocycleRPEOffset))")
                                        .font(.system(size: 10))
                                        .foregroundColor(RQColors.accent.opacity(0.6))
                                }
                            }

                            if target.e1rmConfidence < 0.85 {
                                HStack(spacing: RQSpacing.xs) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(RQColors.textTertiary)
                                    Text("High-rep est. (\(Int(target.e1rmConfidence * 100))% confidence)")
                                        .font(.system(size: 10))
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                        }
                    }
                    .padding(.top, RQSpacing.xxs)
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
                    Text("\(exercise.repRangeDisplay) reps")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    Text("RPE \(formatRPE(exercise.trainingMode.targetRPE))")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Prescription

    /// The session's instruction, sized to be read from the rack rather than at
    /// arm's length. Bodyweight lifts have no load to show, so reps carry the
    /// poster weight instead.
    @ViewBuilder
    private func prescriptionFigure(_ exercise: ExerciseLogEntry, _ target: ProgressionTarget) -> some View {
        let usesLoad = !(exercise.isBodyweightOnly && !exercise.useAddedWeight)

        HStack(alignment: .firstTextBaseline, spacing: RQSpacing.xs) {
            if usesLoad {
                Text(formatWeight(target.targetWeight))
                    .font(RQTypography.poster)
                    .foregroundColor(RQColors.textPrimary)
            } else {
                Text("BW")
                    .font(RQTypography.hero)
                    .foregroundColor(RQColors.textSecondary)
            }

            Text("×")
                .font(RQTypography.title2)
                .foregroundColor(RQColors.textTertiary)

            Text("\(target.targetRepsLow)")
                .font(usesLoad ? RQTypography.hero : RQTypography.poster)
                .foregroundColor(RQColors.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private func prescriptionStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .rqLabel()
                .foregroundColor(RQColors.textTertiary)
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textSecondary)
        }
    }

    /// Hypertrophy climbs 0.5 per set from the base; strength ramps from 6.
    private func targetRPEDisplay(_ exercise: ExerciseLogEntry, _ target: ProgressionTarget) -> String {
        if exercise.trainingMode == .hypertrophy {
            let base = target.targetRPE
            let top = min(base + Double(exercise.targetSets - 1) * 0.5, 9.0)
            return "\(formatRPE(base))–\(formatRPE(top))"
        }
        return "6–\(formatRPE(target.targetRPE))"
    }

    // MARK: - Decision Helpers

    private func decisionTopic(_ target: ProgressionTarget) -> ProgressExplainer.Topic {
        let (title, icon, explanation, keyPoints, howToUse): (String, String, String, [String], String)

        let isStrength = target.trainingMode == .strength

        switch target.decision {
        case .increaseWeight:
            title = "Increase Weight"
            icon = "arrow.up.circle.fill"
            explanation = target.reasoning
            keyPoints = isStrength
                ? [
                    "Your top set reached the top of its rep range last session.",
                    "The size of the jump comes from your estimated 1RM, which is reliable at 3–5 reps.",
                    "Reps reset to the bottom of the range — this is normal.",
                ]
                : [
                    "Every working set reached the top of your rep range last session.",
                    "Weight goes up by one equipment increment, not by a percentage — beating the range earns the jump sooner, not a bigger one.",
                    "Reps reset to the bottom of the range — this is normal.",
                ]
            howToUse = "Focus on hitting the target weight for the prescribed reps on each set. If you can't reach the bottom of the range, the weight holds next session while you rebuild."

        case .increaseReps:
            title = "Increase Reps"
            icon = "arrow.up.right.circle.fill"
            explanation = target.reasoning
            keyPoints = isStrength
                ? [
                    "Your top set landed inside the rep range but not at the top of it.",
                    "Adding a rep to the top set at the same weight is how you earn the next increase.",
                    "Reach the top of the range and the weight goes up.",
                ]
                : [
                    "Your sets landed inside the rep range but not all at the top of it.",
                    "Banking reps at the same weight is how you earn the next increase.",
                    "Once every working set hits the top of the range, the weight goes up.",
                ]
            howToUse = "Keep the same weight and aim for the prescribed rep goal, which climbs by one each session you stay in range."

        case .maintain:
            title = "Maintain"
            icon = "arrow.right.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Either you finished below the bottom of the rep range, or the session read as a one-off off-day.",
                "This is not a setback — holding the weight to rebuild is part of the cycle.",
                "Repeating the same performance builds the capacity for the next jump.",
            ]
            howToUse = "Match what you did last session. Focus on form and controlled reps. Consistent effort at the same load builds the foundation for your next progression."

        case .deload:
            title = "Deload"
            icon = "arrow.down.circle.fill"
            explanation = target.reasoning
            keyPoints = [
                "Triggered either by how long it's been since your last deload, or by consecutive sessions with a sharp drop in working weight.",
                "Targets drop to roughly 90% so your body can recover and rebuild.",
                "It's a plan, not a failure — and it's your call. You can decline it and keep progressing.",
            ]
            howToUse = "Use the reduced weight this session. Focus on crisp, controlled reps. You should feel strong again within 1-2 sessions, at which point the engine will push you forward."

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
            HStack(spacing: 2) {
                Text("RPE")
                InfoButton(topic: ProgressExplainer.rpeScale)
            }
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
            // Exclude .warmup — there's a dedicated "Add Warm Up" button
            // above the working sets, so showing it here is redundant.
            ForEach(SetType.allCases.filter { $0 != .warmup }, id: \.self) { type in
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

    private func baselineBanner(_ exercise: ExerciseLogEntry) -> some View {
        let isBodyweight = exercise.isBodyweightOnly
        let mode = exercise.trainingMode
        let repRange = exercise.repRangeDisplay

        let title: String
        let guidance: String
        let repBadge: String?

        if isBodyweight {
            title = "Bodyweight Baseline"
            guidance = "Aim for \(repRange) controlled reps. Leave 2-3 reps in reserve — don't go to complete failure. The app tracks your rep count to generate progression targets."
            repBadge = "\(repRange) reps"
        } else if mode == .strength {
            title = "Strength Baseline"
            guidance = "Start lighter and build up weight across sets toward a challenging top set of \(repRange) reps. Your last set should feel heavy but not a max effort (RPE 7-8). The app will use your top set to calibrate future targets."
            repBadge = "\(repRange) reps"
        } else {
            title = "Hypertrophy Baseline"
            guidance = "Choose a weight you can control for \(repRange) reps with 2-3 reps left in the tank (RPE 7-8). Use the same weight for all sets. It's okay if reps drop on later sets — that's normal fatigue."
            repBadge = "\(repRange) reps"
        }

        return HStack(alignment: .top, spacing: RQSpacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundColor(RQColors.accent)

            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.sm) {
                    Text(title)
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.accent)

                    if let badge = repBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(RQColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RQColors.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(guidance)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.accent.opacity(0.08))
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Helpers

    private var modeColor: Color {
        exercise?.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
    }

    private func modeColorFor(_ mode: TrainingMode) -> Color {
        mode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
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
