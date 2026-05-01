import SwiftUI

struct SetRowView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let setIndex: Int
    var previousSet: WorkoutSet? = nil
    var progressionTarget: ProgressionTarget? = nil
    var setPosition: Int = 0
    @FocusState private var focusedField: Field?
    @State private var feedbackExpanded = false
    @State private var feedbackMinimized = false

    private enum Field {
        case weight, reps
    }

    private var set: SetEntry? {
        viewModel.exercises[safe: exerciseIndex]?.sets[safe: setIndex]
    }

    private var totalWorkingSets: Int {
        viewModel.exercises[safe: exerciseIndex]?.targetSets ?? 4
    }

    private var trainingMode: TrainingMode {
        viewModel.exercises[safe: exerciseIndex]?.trainingMode ?? .hypertrophy
    }

    private var equipment: String {
        viewModel.exercises[safe: exerciseIndex]?.equipment ?? ""
    }

    private var isBodyweightOnly: Bool {
        viewModel.exercises[safe: exerciseIndex]?.isBodyweightOnly ?? false
    }

    private var repRangeDisplay: String {
        viewModel.exercises[safe: exerciseIndex]?.repRangeDisplay ?? "10-15"
    }

    private var showPlateBreakdown: Bool {
        (equipment == "barbell" || equipment == "smith_machine") && (set?.weight ?? 0) > AppConstants.Defaults.barWeight
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showNotes: Bool = false
    @State private var notesText: String = ""

    var body: some View {
        guard let set else { return AnyView(EmptyView()) }

        let isWorking = set.setType == .working

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Ghost row — per-set target (decision + previous set) or previous fallback
                if let target = progressionTarget, isWorking {
                    // Compute mode-aware per-set target from progression decision + this set's previous data
                    let (targetW, targetR, _) = ActiveWorkoutViewModel.perSetTarget(
                        decision: target, previousSet: previousSet,
                        trainingMode: trainingMode, setPosition: setPosition,
                        totalSets: totalWorkingSets, equipment: equipment
                    )

                    HStack(spacing: RQSpacing.xs) {
                        Spacer().frame(width: 32)

                        Text("Target")
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.accent.opacity(0.6))

                        if isBodyweightOnly {
                            Text("\(targetR) reps")
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.accent.opacity(0.7))
                        } else {
                            Text("\(formatWeight(targetW)) × \(targetR)")
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.accent.opacity(0.7))
                        }

                        // Declining reps note for later hypertrophy sets (Gap 2)
                        if trainingMode == .hypertrophy && setPosition >= 2 && !isBodyweightOnly {
                            Text("(drop 1-2 reps is normal)")
                                .font(.system(size: 9))
                                .foregroundColor(RQColors.textTertiary.opacity(0.6))
                        }

                        Spacer()
                    }
                    .padding(.bottom, 3)

                    // Previous-set line with delta (always show below the target if data exists)
                    if let prev = previousSet {
                        previousSetLine(prev: prev, comparisonWeight: targetW, comparisonReps: targetR, showDelta: true)
                    }
                } else if let prev = previousSet {
                    // No target — show raw previous session data. For non-working sets
                    // we still show the previous data for context, but no delta arrow
                    // since warmups/drops/etc. aren't progression-tracked.
                    previousSetLine(prev: prev, comparisonWeight: nil, comparisonReps: nil, showDelta: false)
                } else if isWorking && !set.isCompleted {
                    // Baseline hint — only show on working sets without target or previous data
                    HStack(spacing: RQSpacing.xs) {
                        Spacer().frame(width: 32)

                        Image(systemName: "scope")
                            .font(.system(size: 9))
                            .foregroundColor(RQColors.accent.opacity(0.5))

                        Group {
                            if isBodyweightOnly {
                                Text("Aim for \(repRangeDisplay) reps @ RPE 7-8")
                            } else if trainingMode == .strength {
                                if setPosition >= totalWorkingSets - 1 {
                                    Text("Top set — \(repRangeDisplay) reps @ RPE 7-8")
                                } else {
                                    Text("Build up — lighter than top set")
                                }
                            } else {
                                Text("Aim for \(repRangeDisplay) reps @ RPE 7-8")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.accent.opacity(0.5))

                        Spacer()
                    }
                    .padding(.bottom, 2)
                }

                // Fill target button — one-tap to match target/previous values
                if !set.isCompleted && hasTargetValues && weightText.isEmpty && repsText.isEmpty {
                    Button {
                        fillFromTarget()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 10, weight: .bold))
                            Text("Fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(RQColors.accent)
                        .padding(.horizontal, RQSpacing.sm)
                        .padding(.vertical, 4)
                        .background(RQColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 32)
                    .padding(.bottom, 2)
                }

                // Input row
                HStack(spacing: RQSpacing.sm) {
                    // Set number badge
                    Text("\(set.setNumber)")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(set.isCompleted ? RQColors.background : setTypeColor)
                        .frame(width: 26, height: 26)
                        .background(set.isCompleted ? setTypeColor : setTypeColor.opacity(0.2))
                        .clipShape(Circle())

                    if isBodyweightOnly {
                        // Bodyweight label instead of weight input
                        Text("BW")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.textTertiary)
                            .frame(width: 64, height: 36)
                            .background(RQColors.surfaceTertiary.opacity(0.5))
                            .cornerRadius(RQRadius.small)

                        Text("×")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    } else {
                        // Weight input
                        TextField(weightPlaceholder, text: $weightText)
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(set.isCompleted ? RQColors.textSecondary : RQColors.textPrimary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 64, height: 36)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.small)
                            .focused($focusedField, equals: .weight)
                            .disabled(set.isCompleted)
                            .toolbar {
                                if focusedField == .weight {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Done") { focusedField = nil }
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(RQColors.accent)
                                    }
                                }
                            }
                            .onChange(of: weightText) { _, newValue in
                                if let weight = Double(newValue) {
                                    viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight)
                                }
                            }

                        Text("×")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    // Reps input
                    TextField(repsPlaceholder, text: $repsText)
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(set.isCompleted ? RQColors.textSecondary : RQColors.textPrimary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 48, height: 36)
                        .background(RQColors.surfaceTertiary)
                        .cornerRadius(RQRadius.small)
                        .focused($focusedField, equals: .reps)
                        .disabled(set.isCompleted)
                        .toolbar {
                            if focusedField == .reps {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { focusedField = nil }
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(RQColors.accent)
                                }
                            }
                        }
                        .onChange(of: repsText) { _, newValue in
                            if let reps = Int(newValue) {
                                viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: reps)
                            }
                        }

                    Text("@")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    // RPE badge
                    rpeBadge(set: set)

                    Spacer()

                    // PR badge
                    if let prType = set.prType, set.isCompleted {
                        HStack(spacing: 2) {
                            Image(systemName: prType.icon)
                                .font(.system(size: 10))
                            Text(prType.label)
                                .font(.system(size: 9, weight: .black))
                                .lineLimit(1)
                        }
                        .fixedSize()
                        .foregroundColor(RQColors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RQColors.warning.opacity(0.15))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Note toggle button
                    Button {
                        showNotes.toggle()
                        if showNotes { notesText = set.notes ?? "" }
                    } label: {
                        Image(systemName: (set.notes?.isEmpty == false) ? "pencil.circle.fill" : "pencil.circle")
                            .font(.system(size: 20))
                            .foregroundColor((set.notes?.isEmpty == false) ? RQColors.accent.opacity(0.7) : RQColors.textTertiary.opacity(0.5))
                    }

                    // Checkmark button
                    Button {
                        Task {
                            if set.isCompleted {
                                await viewModel.uncompleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                            } else {
                                await viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                focusedField = nil
                            }
                        }
                    } label: {
                        if set.isSaving {
                            ProgressView()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(set.isCompleted ? RQColors.success : RQColors.textTertiary)
                        }
                    }
                    .disabled(set.isSaving)
                }

                // Plate breakdown for barbell exercises
                if showPlateBreakdown {
                    PlateBreakdownView(weight: set.weight)
                }

                // Notes row
                if showNotes {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.textTertiary)

                        TextField("Add a note…", text: $notesText)
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.textPrimary)
                            .onChange(of: notesText) { _, newValue in
                                viewModel.updateNote(exerciseIndex: exerciseIndex, setIndex: setIndex, notes: newValue)
                            }
                    }
                    .padding(.horizontal, RQSpacing.sm)
                    .padding(.vertical, 6)
                    .background(RQColors.surfaceTertiary.opacity(0.6))
                    .cornerRadius(RQRadius.small)
                    .padding(.leading, 32)
                    .padding(.top, RQSpacing.xxs)
                } else if let note = set.notes, !note.isEmpty {
                    // Collapsed preview of existing note
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.textTertiary)
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 32)
                    .padding(.top, RQSpacing.xxs)
                    .onTapGesture { showNotes = true }
                }

                // Coaching feedback chip (working sets only)
                if set.isCompleted, set.setType == .working,
                   let feedback = viewModel.setFeedback[set.id] {
                    SetFeedbackChipView(
                        feedback: feedback,
                        isExpanded: $feedbackExpanded,
                        isMinimized: $feedbackMinimized
                    )
                    .padding(.leading, 32)
                    .padding(.top, RQSpacing.xxs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, RQSpacing.xs)
            .opacity(set.isCompleted ? 0.7 : 1.0)
            .onAppear {
                // Initialize text fields from model
                if set.weight > 0 {
                    weightText = formatWeight(set.weight)
                }
                if set.reps > 0 {
                    repsText = "\(set.reps)"
                }
                notesText = set.notes ?? ""

                // Auto-fill drop and failure sets only (not warmup or cooldown)
                if (set.setType == .drop || set.setType == .failure) && set.weight == 0 && set.reps == 0 {
                    if let prev = previousSet {
                        let w: Double
                        let r: Int
                        if set.setType == .drop {
                            w = (prev.weight * 0.7 / 5).rounded() * 5
                            r = prev.reps + 2
                        } else {
                            w = prev.weight
                            r = prev.reps
                        }
                        weightText = formatWeight(w)
                        repsText = "\(r)"
                        viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: w)
                        viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: r)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func rpeBadge(set: SetEntry) -> some View {
        Menu {
            Button("None") {
                viewModel.updateRPE(exerciseIndex: exerciseIndex, setIndex: setIndex, rpe: nil)
            }
            ForEach(rpeValues, id: \.self) { value in
                Button(formatRPE(value)) {
                    viewModel.updateRPE(exerciseIndex: exerciseIndex, setIndex: setIndex, rpe: value)
                }
            }
        } label: {
            Text(set.rpe.map { formatRPE($0) } ?? "RPE")
                .font(RQTypography.numbersSmall)
                .foregroundColor(set.rpe != nil ? RQColors.textPrimary : RQColors.textTertiary)
                .frame(width: 56, height: 36)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.small)
        }
        .disabled(set.isCompleted)
    }

    private var setTypeColor: Color {
        guard let set else { return RQColors.working }
        switch set.setType {
        case .warmup: return RQColors.warmup
        case .working: return RQColors.working
        case .cooldown: return RQColors.cooldown
        case .drop: return RQColors.dropSet
        case .failure: return RQColors.failure
        }
    }

    private var modeColor: Color {
        trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength
    }

    /// Smart placeholder showing the target weight when the field is empty.
    private var weightPlaceholder: String {
        if let target = progressionTarget {
            let (w, _, _) = ActiveWorkoutViewModel.perSetTarget(
                decision: target, previousSet: previousSet,
                trainingMode: trainingMode, setPosition: setPosition,
                equipment: equipment
            )
            return w > 0 ? formatWeight(w) : "0"
        }
        return previousSet.map { formatWeight($0.weight) } ?? "0"
    }

    /// Smart placeholder showing the target reps when the field is empty.
    private var repsPlaceholder: String {
        if let target = progressionTarget {
            let (_, r, _) = ActiveWorkoutViewModel.perSetTarget(
                decision: target, previousSet: previousSet,
                trainingMode: trainingMode, setPosition: setPosition,
                equipment: equipment
            )
            return r > 0 ? "\(r)" : "0"
        }
        return previousSet.map { "\($0.reps)" } ?? "0"
    }

    // MARK: - Fill Helpers

    private var hasTargetValues: Bool {
        if progressionTarget != nil { return true }
        if previousSet != nil { return true }
        return false
    }

    private func fillFromTarget() {
        let (w, r, rpe): (Double, Int, Double)
        if let target = progressionTarget {
            (w, r, rpe) = ActiveWorkoutViewModel.perSetTarget(
                decision: target, previousSet: previousSet,
                trainingMode: trainingMode, setPosition: setPosition,
                equipment: equipment
            )
        } else if let prev = previousSet {
            (w, r, rpe) = (prev.weight, prev.reps, prev.rpe ?? 0)
        } else {
            return
        }

        if !isBodyweightOnly {
            weightText = formatWeight(w)
            viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: w)
        }
        repsText = "\(r)"
        viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: r)
        if rpe > 0 {
            viewModel.updateRPE(exerciseIndex: exerciseIndex, setIndex: setIndex, rpe: rpe)
        }
    }

    private let rpeValues: [Double] = Array(stride(from: 1.0, through: 10.0, by: 1.0))

    private func formatRPE(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    // MARK: - Previous-Set Line

    /// Renders a single muted line showing the previous session's set values, with
    /// an optional delta arrow comparing to the current target.
    /// Examples:
    ///   "Last: 150 × 12 @ 8  ▲5 lb"   (working set, more weight than target)
    ///   "Last: 150 × 12  ▲1 rep"      (working set, same weight + more reps)
    ///   "Last: 150 × 12  ="            (working set, same as last time)
    ///   "Last: 45 × 10"                (warmup — no delta arrow)
    @ViewBuilder
    private func previousSetLine(
        prev: WorkoutSet,
        comparisonWeight: Double?,
        comparisonReps: Int?,
        showDelta: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Spacer().frame(width: 32)

            Text("Last:")
                .font(.system(size: 10))
                .foregroundColor(RQColors.textTertiary.opacity(0.7))

            if isBodyweightOnly {
                Text("\(prev.reps) reps")
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary.opacity(0.7))
            } else {
                Text("\(formatWeight(prev.weight)) × \(prev.reps)")
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary.opacity(0.7))
            }

            if let rpe = prev.rpe {
                Text("@ \(formatRPE(rpe))")
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary.opacity(0.55))
            }

            if showDelta, let curW = comparisonWeight, let curR = comparisonReps {
                deltaBadge(prevWeight: prev.weight, prevReps: prev.reps, curWeight: curW, curReps: curR)
            }

            Spacer()
        }
        .padding(.bottom, 2)
    }

    /// Small inline delta badge comparing target to previous session.
    /// - Heavier weight → green ▲ +N lb
    /// - Same weight + more reps → green ▲ +N rep
    /// - Identical → gray =
    /// - Lighter weight → orange ▼ −N lb (intentional deload)
    @ViewBuilder
    private func deltaBadge(prevWeight: Double, prevReps: Int, curWeight: Double, curReps: Int) -> some View {
        let weightDelta = curWeight - prevWeight
        let repsDelta = curReps - prevReps

        if weightDelta > 0.001 {
            // Heavier
            HStack(spacing: 1) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7, weight: .bold))
                Text("\(formatWeight(weightDelta)) lb")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(RQColors.success)
        } else if weightDelta < -0.001 {
            // Lighter
            HStack(spacing: 1) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 7, weight: .bold))
                Text("\(formatWeight(abs(weightDelta))) lb")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(RQColors.warning)
        } else if repsDelta > 0 {
            // Same weight, more reps
            HStack(spacing: 1) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7, weight: .bold))
                Text("\(repsDelta) rep\(repsDelta == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(RQColors.success)
        } else if repsDelta < 0 {
            // Same weight, fewer reps
            HStack(spacing: 1) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 7, weight: .bold))
                Text("\(abs(repsDelta)) rep\(abs(repsDelta) == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(RQColors.warning)
        } else {
            // Identical
            Text("=")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(RQColors.textTertiary.opacity(0.7))
        }
    }
}
