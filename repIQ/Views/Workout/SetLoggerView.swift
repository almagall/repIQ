import SwiftUI

/// The per-exercise set logger. A pinned hero ring answers "what am I doing
/// right now" (the live set's prescription, or the rest countdown between
/// sets) while the adjust blocks, log button, and the exercise ledger scroll
/// beneath it. Replaces the form-style ExerciseLogView/SetRowView stack: the
/// prescription is prefilled into the pending set, so logging an as-planned
/// set is a single tap on the Log button.
struct SetLoggerView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int

    @State private var showWeightEntry = false
    @State private var showRepsEntry = false
    @State private var weightEntryText = ""
    @State private var repsEntryText = ""
    @State private var setToDelete: Int?
    @State private var showDeleteConfirmation = false
    @State private var warmupSuggestionDismissed = false

    private var exercise: ExerciseLogEntry? {
        viewModel.exercises[safe: exerciseIndex]
    }

    /// First incomplete set in display order. Warmups sort before working
    /// sets, so they become the live set naturally.
    private var liveSetIndex: Int? {
        exercise?.sets.firstIndex(where: { !$0.isCompleted })
    }

    private var liveSet: SetEntry? {
        guard let index = liveSetIndex else { return nil }
        return exercise?.sets[safe: index]
    }

    private var usesLoad: Bool {
        guard let exercise else { return true }
        return !(exercise.isBodyweightOnly && !exercise.useAddedWeight)
    }

    // Pound-canonical, matching stored set weights app-wide.
    private let weightUnit = "lb"

    private var fineIncrement: Double { 2.5 }

    private var coarseIncrement: Double {
        max(ProgressionService.weightIncrement(for: exercise?.equipment ?? ""), 5.0)
    }

    var body: some View {
        guard let exercise else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                heroRing(exercise)
                    .padding(.top, RQSpacing.md)
                    .padding(.bottom, RQSpacing.lg)
                    .background(
                        RadialGradient(
                            colors: [RQColors.accent.opacity(0.07), .clear],
                            center: .center, startRadius: 10, endRadius: 170
                        )
                    )

                ScrollView {
                    VStack(spacing: RQSpacing.md) {
                        if let group = exercise.supersetGroup {
                            supersetStrip(exercise, group: group)
                        }

                        if let set = liveSet, set.setType == .working {
                            targetLastCard(exercise, set: set)
                        }

                        if let set = liveSet {
                            if usesLoad {
                                weightBlock(exercise, set: set)
                            }
                            repsBlock(exercise, set: set)
                            if set.setType == .working {
                                rpeBlock(set: set)
                            }
                        }

                        if viewModel.restTimerActive {
                            restControls
                            coachCard(exercise)
                        }

                        if let set = liveSet {
                            logButton(exercise, set: set)
                        }

                        if shouldShowWarmupSuggestion(exercise) {
                            warmupSuggestionCard(exercise)
                        }

                        ledger(exercise)
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.xs)
                    .padding(.bottom, RQSpacing.xxxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .alert("Enter weight", isPresented: $showWeightEntry) {
                TextField("Weight (\(weightUnit))", text: $weightEntryText)
                    .keyboardType(.decimalPad)
                Button("Set") {
                    if let index = liveSetIndex, let weight = Double(weightEntryText), weight >= 0 {
                        viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: index, weight: weight)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Enter reps", isPresented: $showRepsEntry) {
                TextField("Reps", text: $repsEntryText)
                    .keyboardType(.numberPad)
                Button("Set") {
                    if let index = liveSetIndex, let reps = Int(repsEntryText), reps >= 0 {
                        viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: index, reps: reps)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Set?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let index = setToDelete {
                        Task { await viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: index) }
                    }
                    setToDelete = nil
                }
                Button("Cancel", role: .cancel) { setToDelete = nil }
            } message: {
                if let index = setToDelete, let set = exercise.sets[safe: index], set.isCompleted {
                    Text("This set has been logged. Deleting it will remove it from your workout record.")
                } else {
                    Text("Are you sure you want to remove this set?")
                }
            }
        )
    }

    // MARK: - Hero Ring

    @ViewBuilder
    private func heroRing(_ exercise: ExerciseLogEntry) -> some View {
        let workingSets = exercise.sets.filter { $0.setType == .working }
        let segmentCount = max(workingSets.count, 1)
        let filledCount = workingSets.filter(\.isCompleted).count

        ZStack {
            segmentedRing(count: segmentCount, filled: filledCount)
                .frame(width: 210, height: 210)

            if viewModel.restTimerActive {
                Circle()
                    .trim(from: 0, to: viewModel.restTimerProgress)
                    .stroke(
                        RQColors.stateAdvancing.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 178, height: 178)
                    .animation(.linear(duration: 1), value: viewModel.restTimerProgress)
            }

            ringCenter(exercise, workingSets: workingSets, filledCount: filledCount)
        }
    }

    /// The set-progress track: one arc segment per working set, filled in
    /// accent as sets complete. Warmups never earn a segment — the ring tells
    /// the progression story, and only working sets are part of it.
    @ViewBuilder
    private func segmentedRing(count: Int, filled: Int) -> some View {
        let gap = 0.030
        let span = (1.0 / Double(count)) - gap

        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let start = Double(index) / Double(count) + gap / 2
                Circle()
                    .trim(from: start, to: start + span)
                    .stroke(
                        index < filled ? RQColors.accent : RQColors.hairline,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    @ViewBuilder
    private func ringCenter(_ exercise: ExerciseLogEntry, workingSets: [SetEntry], filledCount: Int) -> some View {
        if viewModel.restTimerActive {
            VStack(spacing: 5) {
                Text("RESTING")
                    .rqLabel()
                    .foregroundColor(RQColors.stateAdvancing)
                Text(viewModel.restTimerDisplay)
                    .font(RQTypography.targetWeight)
                    .foregroundColor(RQColors.textPrimary)
                Text(restUntilText(exercise, workingSets: workingSets))
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
        } else if let set = liveSet {
            VStack(spacing: 6) {
                if set.setType == .warmup {
                    Text("WARM UP \(warmupPosition(of: set, in: exercise) + 1)")
                        .rqLabel()
                        .foregroundColor(RQColors.warmup)
                } else if set.setType == .working {
                    Text("SET \(workingPosition(of: set, in: exercise) + 1) OF \(workingSets.count)")
                        .rqLabel()
                        .foregroundColor(RQColors.textTertiary)
                } else {
                    Text(set.setType.rawValue.uppercased())
                        .rqLabel()
                        .foregroundColor(setTypeColor(set.setType))
                }

                if usesLoad {
                    Button { presentWeightEntry(set) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(set.weight > 0 ? formatWeight(set.weight) : "—")
                                .font(.system(size: 46, weight: .heavy, design: .monospaced))
                                .foregroundColor(RQColors.textPrimary)
                            Text(weightUnit)
                                .font(RQTypography.footnote)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button { presentRepsEntry(set) } label: {
                        Text("× \(set.reps) reps")
                            .font(RQTypography.callout)
                            .foregroundColor(RQColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { presentRepsEntry(set) } label: {
                        VStack(spacing: 2) {
                            Text("\(set.reps)")
                                .font(.system(size: 46, weight: .heavy, design: .monospaced))
                                .foregroundColor(RQColors.textPrimary)
                            Text("reps")
                                .font(RQTypography.footnote)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(RQColors.accent)
                Text("\(filledCount) OF \(workingSets.count)")
                    .font(RQTypography.title3)
                    .foregroundColor(RQColors.textPrimary)
                Text("COMPLETE")
                    .rqLabel()
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    private func restUntilText(_ exercise: ExerciseLogEntry, workingSets: [SetEntry]) -> String {
        if exercise.supersetGroup != nil {
            let indices = viewModel.currentGroupIndices
            if indices.count > 1 {
                return "until round \(viewModel.supersetCurrentRound(for: indices))"
            }
        }
        if let set = liveSet, set.setType == .working {
            return "until set \(workingPosition(of: set, in: exercise) + 1)"
        }
        return "rest"
    }

    // MARK: - Superset Strip

    @ViewBuilder
    private func supersetStrip(_ exercise: ExerciseLogEntry, group: Int) -> some View {
        let members = viewModel.supersetExercises(for: exerciseIndex)
        if members.count > 1,
           let myPosition = members.firstIndex(where: { $0.index == exerciseIndex }) {
            let partner = members[(myPosition + 1) % members.count]

            Button {
                viewModel.currentExerciseIndex = partner.index
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RQColors.supersetGold)
                    Text("then")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                    Text(partner.entry.exerciseName)
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("NO REST")
                        .rqLabel()
                        .foregroundColor(RQColors.supersetGold)
                }
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(RQColors.supersetGold.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                        .stroke(RQColors.supersetGold.opacity(0.25), lineWidth: 0.5)
                )
                .cornerRadius(RQRadius.large)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Target / Last Card

    @ViewBuilder
    private func targetLastCard(_ exercise: ExerciseLogEntry, set: SetEntry) -> some View {
        let previous = previousWorkingSet(for: set, in: exercise)

        VStack(spacing: 0) {
            if exercise.progressionTarget != nil {
                HStack(spacing: RQSpacing.sm) {
                    Circle().fill(RQColors.accent).frame(width: 6, height: 6)
                    Text("Target")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text(targetLine(exercise, weight: set.targetWeight, reps: set.targetReps, rpe: set.targetRPE))
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                    deviationTag(set: set, targetWeight: set.targetWeight, targetReps: set.targetReps)
                }
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.md)
            } else {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RQColors.accent)
                    Text("First time — set your baseline")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text("pick a weight you can lift \(exercise.repRangeDisplay) times")
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.md)
            }

            if let previous {
                Divider().background(RQColors.hairline)

                HStack(spacing: RQSpacing.sm) {
                    Circle().fill(RQColors.textTertiary).frame(width: 6, height: 6)
                    Text("Last")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text(previousLine(previous))
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textSecondary)
                }
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.md)
            }
        }
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.hairline, lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
    }

    /// Hypertrophy targets deliberately omit the prescribed RPE: its decisions
    /// are rep-driven and the per-set RPE curve is an expectation, not an
    /// instruction. Strength keeps it — the top-set RPE genuinely guides the ramp.
    private func targetLine(_ exercise: ExerciseLogEntry, weight: Double, reps: Int, rpe: Double?) -> String {
        let core = usesLoad ? "\(formatWeight(weight)) × \(reps)" : "\(reps) reps"
        if exercise.trainingMode == .strength, let rpe {
            return "\(core) @\(formatRPE(rpe))"
        }
        return core
    }

    private func previousLine(_ previous: WorkoutSet) -> String {
        let core = usesLoad ? "\(formatWeight(previous.weight)) × \(previous.reps)" : "\(previous.reps) reps"
        if let rpe = previous.rpe, rpe > 0 {
            return "\(core) @\(formatRPE(rpe))"
        }
        return core
    }

    @ViewBuilder
    private func deviationTag(set: SetEntry, targetWeight: Double, targetReps: Int) -> some View {
        let weightDelta = set.weight - targetWeight
        let repsDelta = set.reps - targetReps

        if abs(weightDelta) < 0.001 && repsDelta == 0 {
            Text("matched")
                .font(.system(size: 10))
                .foregroundColor(RQColors.textTertiary)
        } else {
            Text(deviationText(weightDelta: weightDelta, repsDelta: repsDelta))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RQColors.stateHolding)
        }
    }

    private func deviationText(weightDelta: Double, repsDelta: Int) -> String {
        var parts: [String] = []
        if abs(weightDelta) >= 0.001, usesLoad {
            parts.append("\(weightDelta > 0 ? "+" : "−")\(formatWeight(abs(weightDelta))) \(weightUnit)")
        }
        if repsDelta != 0 {
            parts.append("\(repsDelta > 0 ? "+" : "−")\(abs(repsDelta)) rep\(abs(repsDelta) == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Weight Block

    @ViewBuilder
    private func weightBlock(_ exercise: ExerciseLogEntry, set: SetEntry) -> some View {
        let showPlates = (exercise.equipment == "barbell" || exercise.equipment == "smith_machine")
            && set.weight > AppConstants.Defaults.barWeight

        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("WEIGHT")
                .rqLabel()
                .foregroundColor(RQColors.textTertiary)

            HStack(spacing: RQSpacing.xs) {
                stepperButton("−\(formatWeight(coarseIncrement))") { adjustWeight(set, by: -coarseIncrement) }
                stepperButton(icon: "minus") { adjustWeight(set, by: -fineIncrement) }

                Spacer(minLength: RQSpacing.xs)

                if showPlates {
                    Button { presentWeightEntry(set) } label: {
                        PlateBreakdownView(weight: set.weight)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { presentWeightEntry(set) } label: {
                        Text(set.weight > 0 ? formatWeight(set.weight) : "—")
                            .font(RQTypography.numbers)
                            .foregroundColor(set.weight > 0 ? RQColors.textPrimary : RQColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: RQSpacing.xs)

                stepperButton(icon: "plus") { adjustWeight(set, by: fineIncrement) }
                stepperButton("+\(formatWeight(coarseIncrement))") { adjustWeight(set, by: coarseIncrement) }
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.hairline, lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
    }

    // MARK: - Reps Block

    @ViewBuilder
    private func repsBlock(_ exercise: ExerciseLogEntry, set: SetEntry) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Text("REPS")
                .rqLabel()
                .foregroundColor(RQColors.textTertiary)

            Button { presentRepsEntry(set) } label: {
                Text("\(set.reps)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)
            }
            .buttonStyle(.plain)

            if set.setType == .working, exercise.progressionTarget != nil {
                repsStatusNote(reps: set.reps, target: set.targetReps)
            }

            Spacer()

            stepperButton(icon: "minus") {
                if set.reps > 0, let index = liveSetIndex {
                    viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: index, reps: set.reps - 1)
                }
            }
            stepperButton(icon: "plus") {
                if let index = liveSetIndex {
                    viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: index, reps: set.reps + 1)
                }
            }
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.hairline, lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
    }

    @ViewBuilder
    private func repsStatusNote(reps: Int, target: Int) -> some View {
        let delta = reps - target
        if delta == 0 {
            Text("on target")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(RQColors.stateAdvancing)
        } else if delta > 0 {
            Text("+\(delta) vs target")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(RQColors.stateAdvancing)
        } else {
            Text("\(delta) vs target")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(RQColors.stateHolding)
        }
    }

    // MARK: - RPE Block

    /// Whole numbers only, never prefilled: a target-seeded default would feed
    /// fabricated effort into the progression engine. Unrated stays nil and
    /// the engine degrades cleanly.
    @ViewBuilder
    private func rpeBlock(set: SetEntry) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack {
                Text("RPE")
                    .rqLabel()
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
                if let rpe = set.rpe {
                    Text(repsLeftText(rpe: rpe))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rpeHeat(Int(rpe)))
                } else {
                    Text("optional — how hard was it?")
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { value in
                    rpeChip(value: value, set: set)
                }
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.hairline, lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
    }

    @ViewBuilder
    private func rpeChip(value: Int, set: SetEntry) -> some View {
        let isSelected = set.rpe.map { Int($0) == value } ?? false
        let heat = rpeHeat(value)

        Button {
            guard let index = liveSetIndex else { return }
            viewModel.updateRPE(
                exerciseIndex: exerciseIndex,
                setIndex: index,
                rpe: isSelected ? nil : Double(value)
            )
        } label: {
            Text("\(value)")
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.sm)
                .background(isSelected ? heat : heat.opacity(0.10 + Double(value) * 0.008))
                .cornerRadius(RQRadius.small)
        }
        .buttonStyle(.plain)
    }

    private func rpeHeat(_ value: Int) -> Color {
        switch value {
        case ...5: return RQColors.stateAdvancing
        case 6...8: return RQColors.stateHolding
        default: return RQColors.stateBacking
        }
    }

    private func repsLeftText(rpe: Double) -> String {
        let left = max(0, 10 - Int(rpe))
        if left == 0 { return "max effort" }
        return "\(left) rep\(left == 1 ? "" : "s") left"
    }

    // MARK: - Rest Controls + Coach

    private var restControls: some View {
        HStack(spacing: RQSpacing.sm) {
            Button {
                viewModel.adjustRunningTimer(by: 30)
            } label: {
                Text("+30 sec")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.surfaceTertiary)
                    .cornerRadius(RQRadius.extraLarge)
            }

            Button {
                viewModel.cancelRestTimer()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Skip rest")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(RQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.md)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.extraLarge)
            }
        }
    }

    /// Post-set coaching for the set just logged, shown while resting — the
    /// one moment mid-workout the user is actually reading the screen.
    @ViewBuilder
    private func coachCard(_ exercise: ExerciseLogEntry) -> some View {
        let feedback = exercise.sets
            .filter(\.isCompleted)
            .compactMap { viewModel.setFeedback[$0.id] }
            .last

        if let feedback {
            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                Text("COACH")
                    .rqLabel()
                    .foregroundColor(feedback.outcome.color)

                Text(feedback.headline)
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feedback.detail)
                    .font(.system(size: 11))
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RQSpacing.md)
            .background(RQColors.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                    .stroke(feedback.outcome.color.opacity(0.3), lineWidth: 0.5)
            )
            .cornerRadius(RQRadius.large)
        }
    }

    // MARK: - Log Button

    @ViewBuilder
    private func logButton(_ exercise: ExerciseLogEntry, set: SetEntry) -> some View {
        let disabled = (usesLoad && set.weight <= 0) || set.reps <= 0 || set.isSaving
        let isWarmup = set.setType == .warmup

        VStack(spacing: RQSpacing.sm) {
            Button {
                guard let index = liveSetIndex else { return }
                Task {
                    await viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: index)
                    advanceSupersetIfNeeded()
                }
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    if set.isSaving {
                        ProgressView()
                            .tint(isWarmup ? RQColors.warmup : RQColors.background)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(logButtonTitle(set: set, isWarmup: isWarmup))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                .foregroundColor(isWarmup ? RQColors.warmup : RQColors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.lg)
                .background(isWarmup ? Color.clear : RQColors.accent)
                .overlay(
                    Capsule().stroke(
                        isWarmup ? RQColors.warmup : Color.clear,
                        lineWidth: isWarmup ? 1 : 0
                    )
                )
                .clipShape(Capsule())
                .opacity(disabled ? 0.35 : 1)
            }
            .disabled(disabled)

            if set.setType == .working, exercise.progressionTarget != nil {
                Text("PREFILLED FROM YOUR TARGET — ONE TAP IF YOU HIT IT")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    private func logButtonTitle(set: SetEntry, isWarmup: Bool) -> String {
        let prefix = isWarmup ? "Log warmup" : "Log"
        let core: String
        if usesLoad {
            core = "\(prefix) \(formatWeight(set.weight)) × \(set.reps)"
        } else {
            core = "\(prefix) \(set.reps) reps"
        }
        if set.setType == .working, let rpe = set.rpe {
            return "\(core) @\(formatRPE(rpe))"
        }
        return core
    }

    /// After logging a superset member's set, jump straight to the partner —
    /// no rest inside the round. The VM's rest logic is already round-aware
    /// (rest starts only when the round's last member completes).
    private func advanceSupersetIfNeeded() {
        guard exercise?.supersetGroup != nil else { return }
        let members = viewModel.supersetExercises(for: exerciseIndex)
        guard members.count > 1,
              let myPosition = members.firstIndex(where: { $0.index == exerciseIndex }) else { return }

        let partner = members[(myPosition + 1) % members.count]
        if partner.entry.sets.contains(where: { !$0.isCompleted }) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.currentExerciseIndex = partner.index
            }
        }
    }

    // MARK: - Warmup Suggestion

    private func shouldShowWarmupSuggestion(_ exercise: ExerciseLogEntry) -> Bool {
        !warmupSuggestionDismissed
            && exercise.completedWorkingSetCount == 0
            && !exercise.sets.contains(where: { $0.setType == .warmup })
            && viewModel.shouldSuggestWarmup(exerciseIndex: exerciseIndex)
    }

    /// Suggests ramp weights as guidance text only — warmup sets are never
    /// pre-filled (hard constraint), so Apply inserts empty sets.
    @ViewBuilder
    private func warmupSuggestionCard(_ exercise: ExerciseLogEntry) -> some View {
        HStack(spacing: RQSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("COACH")
                    .rqLabel()
                    .foregroundColor(RQColors.warmup)
                if let weights = viewModel.suggestedWarmupWeights(exerciseIndex: exerciseIndex) {
                    Text("Cold start — warm up first? Try ~\(formatWeight(weights.warmup1)) then ~\(formatWeight(weights.warmup2)).")
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Cold start — add a couple of warmup sets first?")
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.textSecondary)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    viewModel.addSet(exerciseIndex: exerciseIndex, setType: .warmup)
                    viewModel.addSet(exerciseIndex: exerciseIndex, setType: .warmup)
                    warmupSuggestionDismissed = true
                }
            } label: {
                Text("Add 2")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.warmup)
                    .padding(.horizontal, RQSpacing.lg)
                    .padding(.vertical, RQSpacing.sm)
                    .background(RQColors.warmup.opacity(0.12))
                    .clipShape(Capsule())
            }

            Button {
                withAnimation { warmupSuggestionDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(RQColors.textTertiary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.warmup.opacity(0.3), lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
    }

    // MARK: - Ledger

    @ViewBuilder
    private func ledger(_ exercise: ExerciseLogEntry) -> some View {
        let workingSets = exercise.sets.filter { $0.setType == .working }
        let logged = workingSets.filter(\.isCompleted).count

        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack {
                Text("THIS EXERCISE")
                    .rqLabel()
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
                Text("\(logged) OF \(workingSets.count) LOGGED")
                    .rqLabel()
                    .foregroundColor(RQColors.textSecondary)
            }
            .padding(.top, RQSpacing.md)

            // Add-warmup entry point — visible until the working sets begin.
            if exercise.completedWorkingSetCount == 0 {
                addRowButton(label: "Warm up", color: RQColors.warmup) {
                    withAnimation { viewModel.addSet(exerciseIndex: exerciseIndex, setType: .warmup) }
                }
            }

            ForEach(exercise.sets.indices, id: \.self) { index in
                if let set = exercise.sets[safe: index] {
                    SwipeToDeleteWrapper {
                        ledgerRow(exercise, set: set, index: index)
                    } onDelete: {
                        setToDelete = index
                        showDeleteConfirmation = true
                    }
                }
            }

            Menu {
                Button("Working set") {
                    withAnimation { viewModel.addSet(exerciseIndex: exerciseIndex, setType: .working) }
                }
                Button("Drop set") {
                    withAnimation { viewModel.addSet(exerciseIndex: exerciseIndex, setType: .drop) }
                }
                Button("Failure set") {
                    withAnimation { viewModel.addSet(exerciseIndex: exerciseIndex, setType: .failure) }
                }
            } label: {
                addRowLabel(label: "Set", color: RQColors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func ledgerRow(_ exercise: ExerciseLogEntry, set: SetEntry, index: Int) -> some View {
        let isLive = index == liveSetIndex
        let previous = set.setType == .working ? previousWorkingSet(for: set, in: exercise) : nil

        HStack(spacing: RQSpacing.md) {
            ledgerBadge(exercise, set: set)

            VStack(alignment: .leading, spacing: 1) {
                ledgerValueLine(set: set)

                if let previous {
                    Text("last · \(previousLine(previous))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(RQColors.textTertiary)
                }

                if let note = set.notes, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if set.isCompleted {
                verdictTag(set: set, previous: previous)
            } else if isLive {
                Text("NOW")
                    .rqLabel()
                    .foregroundColor(set.setType == .warmup ? RQColors.warmup : RQColors.accent)
            } else {
                Text("UP NEXT")
                    .rqLabel()
                    .foregroundColor(RQColors.textTertiary)
            }
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .background(isLive ? RQColors.accent.opacity(0.05) : RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(isLive ? RQColors.accent.opacity(0.35) : RQColors.hairline, lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
        .opacity(set.isCompleted || isLive ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture {
            if set.isCompleted {
                Task { await viewModel.uncompleteSet(exerciseIndex: exerciseIndex, setIndex: index) }
            }
        }
    }

    @ViewBuilder
    private func ledgerBadge(_ exercise: ExerciseLogEntry, set: SetEntry) -> some View {
        let color = setTypeColor(set.setType)

        if set.isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(RQColors.background)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
        } else {
            Text(ledgerBadgeLabel(exercise, set: set))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(set.setType == .working ? RQColors.textTertiary : color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().stroke(
                        set.setType == .working ? RQColors.surfaceTertiary : color.opacity(0.5),
                        lineWidth: 1
                    )
                )
        }
    }

    private func ledgerBadgeLabel(_ exercise: ExerciseLogEntry, set: SetEntry) -> String {
        switch set.setType {
        case .warmup: return "W\(warmupPosition(of: set, in: exercise) + 1)"
        case .working: return "\(workingPosition(of: set, in: exercise) + 1)"
        case .drop: return "D"
        case .failure: return "F"
        case .cooldown: return "C"
        }
    }

    @ViewBuilder
    private func ledgerValueLine(set: SetEntry) -> some View {
        HStack(spacing: 4) {
            if usesLoad {
                Text("\(formatWeight(set.weight)) \(weightUnit) × \(set.reps)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(set.isCompleted ? RQColors.textPrimary : RQColors.textSecondary)
            } else {
                Text("\(set.reps) reps")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(set.isCompleted ? RQColors.textPrimary : RQColors.textSecondary)
            }

            if let rpe = set.rpe, set.isCompleted {
                Text("@\(formatRPE(rpe))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(RQColors.stateHolding)
            }
        }
    }

    /// Per-set verdict against the same position last session. PR outranks
    /// BEAT; a lighter or shorter set reads MISS in the backing color — a
    /// fact, not a judgment (the single off-day logic decides what it means).
    @ViewBuilder
    private func verdictTag(set: SetEntry, previous: WorkoutSet?) -> some View {
        if set.prType != nil {
            tagPill("PR", color: RQColors.warning)
        } else if let previous, set.setType == .working {
            let beat = set.weight > previous.weight
                || (abs(set.weight - previous.weight) < 0.001 && set.reps > previous.reps)
            let match = abs(set.weight - previous.weight) < 0.001 && set.reps == previous.reps

            if beat {
                tagPill("▲ BEAT", color: RQColors.stateAdvancing)
            } else if match {
                tagPill("MATCH", color: RQColors.textSecondary)
            } else {
                tagPill("▼ MISS", color: RQColors.stateBacking)
            }
        }
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func addRowButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            addRowLabel(label: label, color: color)
        }
        .buttonStyle(.plain)
    }

    private func addRowLabel(label: String, color: Color) -> some View {
        HStack(spacing: RQSpacing.xs) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(RQTypography.caption)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, RQSpacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .foregroundColor(color.opacity(0.4))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func adjustWeight(_ set: SetEntry, by delta: Double) {
        guard let index = liveSetIndex else { return }
        let next = max(0, set.weight + delta)
        viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: index, weight: next)
    }

    private func presentWeightEntry(_ set: SetEntry) {
        weightEntryText = set.weight > 0 ? formatWeight(set.weight) : ""
        showWeightEntry = true
    }

    private func presentRepsEntry(_ set: SetEntry) {
        repsEntryText = set.reps > 0 ? "\(set.reps)" : ""
        showRepsEntry = true
    }

    // MARK: - Helpers

    private func stepperButton(_ label: String = "", icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundColor(RQColors.textSecondary)
            .frame(width: 44, height: 44)
            .background(RQColors.surfaceTertiary)
            .overlay(Circle().stroke(RQColors.hairline, lineWidth: 0.5))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func workingPosition(of set: SetEntry, in exercise: ExerciseLogEntry) -> Int {
        exercise.sets.filter { $0.setType == .working }.firstIndex(where: { $0.id == set.id }) ?? 0
    }

    private func warmupPosition(of set: SetEntry, in exercise: ExerciseLogEntry) -> Int {
        exercise.sets.filter { $0.setType == .warmup }.firstIndex(where: { $0.id == set.id }) ?? 0
    }

    /// Positional comparison: this working set's counterpart from last
    /// session. previousSets is already filtered to working-only at load.
    private func previousWorkingSet(for set: SetEntry, in exercise: ExerciseLogEntry) -> WorkoutSet? {
        guard set.setType == .working else { return nil }
        let position = workingPosition(of: set, in: exercise)
        return exercise.previousSets.first?[safe: position]
    }

    private func setTypeColor(_ type: SetType) -> Color {
        switch type {
        case .warmup: return RQColors.warmup
        case .working: return RQColors.accent
        case .cooldown: return RQColors.cooldown
        case .drop: return RQColors.dropSet
        case .failure: return RQColors.failure
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatRPE(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}
