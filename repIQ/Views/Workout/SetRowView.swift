import SwiftUI

struct SetRowView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let setIndex: Int
    var previousSet: WorkoutSet? = nil
    var progressionTarget: ProgressionTarget? = nil
    var setPosition: Int = 0
    @FocusState private var focusedField: Field?

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

    private var showPlateBreakdown: Bool {
        (equipment == "barbell" || equipment == "smith_machine") && (set?.weight ?? 0) > AppConstants.Defaults.barWeight
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        guard let set else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Ghost row — per-set target (decision + previous set) or previous fallback
                if let target = progressionTarget {
                    // Compute mode-aware per-set target from progression decision + this set's previous data
                    let (targetW, targetR, targetRPE) = ActiveWorkoutViewModel.perSetTarget(
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

                        Text("\(formatWeight(targetW)) × \(targetR)")
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.accent.opacity(0.7))

                        Spacer()
                    }
                    .padding(.bottom, 3)
                } else if let prev = previousSet {
                    // No progression target: show raw previous session data
                    HStack(spacing: RQSpacing.sm) {
                        Spacer().frame(width: 32)

                        Text("Prev:")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        Text("\(formatWeight(prev.weight)) × \(prev.reps)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        if let rpe = prev.rpe {
                            Text("@\(formatRPE(rpe))")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary.opacity(0.6))
                        }

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
                        .onChange(of: weightText) { _, newValue in
                            if let weight = Double(newValue) {
                                viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight)
                            }
                        }

                    Text("×")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

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
                        }
                        .foregroundColor(RQColors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RQColors.warning.opacity(0.15))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
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

        weightText = formatWeight(w)
        repsText = "\(r)"
        viewModel.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: w)
        viewModel.updateReps(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: r)
        if rpe > 0 {
            viewModel.updateRPE(exerciseIndex: exerciseIndex, setIndex: setIndex, rpe: rpe)
        }
    }

    private let rpeValues: [Double] = stride(from: 1.0, through: 10.0, by: 0.5).map { $0 }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
