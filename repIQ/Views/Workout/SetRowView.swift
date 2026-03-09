import SwiftUI

struct SetRowView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int
    let setIndex: Int
    var previousSet: WorkoutSet? = nil
    var progressionTarget: ProgressionTarget? = nil
    @FocusState private var focusedField: Field?

    private enum Field {
        case weight, reps
    }

    private var set: SetEntry? {
        viewModel.exercises[safe: exerciseIndex]?.sets[safe: setIndex]
    }

    private var trainingMode: TrainingMode {
        viewModel.exercises[safe: exerciseIndex]?.trainingMode ?? .hypertrophy
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        guard let set else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Ghost row — target (preferred) or previous session fallback
                if let target = progressionTarget {
                    // Show target: what to aim for
                    HStack(spacing: RQSpacing.sm) {
                        Spacer().frame(width: 32)

                        Text("Target:")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent.opacity(0.5))

                        Text("\(formatWeight(target.targetWeight)) × \(target.targetRepRangeDisplay)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent.opacity(0.5))

                        Text("@\(formatRPE(target.targetRPE))")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent.opacity(0.35))

                        Spacer()
                    }
                    .padding(.bottom, 2)
                } else if let prev = previousSet {
                    // Fallback: show previous session data
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
                    TextField("0", text: $weightText)
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
                    TextField("0", text: $repsText)
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

                    // RPE badge
                    rpeBadge(set: set)

                    Spacer()

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
                                .font(.system(size: 22))
                                .foregroundColor(set.isCompleted ? completionColor(for: set) : RQColors.textTertiary)
                        }
                    }
                    .disabled(set.isSaving)
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
            Text(set.rpe.map { "@\(formatRPE($0))" } ?? "RPE")
                .font(RQTypography.numbersSmall)
                .foregroundColor(set.rpe != nil ? modeColor : RQColors.textTertiary)
                .frame(width: 56, height: 36)
                .background(set.rpe != nil ? modeColor.opacity(0.15) : RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.small)
        }
        .disabled(set.isCompleted)
    }

    /// Returns green if the completed set meets the target, yellow/warning if it missed.
    /// Falls back to green when no target exists.
    private func completionColor(for set: SetEntry) -> Color {
        guard let target = progressionTarget else { return RQColors.success }
        let hitWeight = set.weight >= target.targetWeight
        let hitReps = set.reps >= target.targetRepsLow
        return (hitWeight && hitReps) ? RQColors.success : RQColors.warning
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
