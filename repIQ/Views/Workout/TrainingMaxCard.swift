import SwiftUI

/// Asked once, the first time a 5/3/1 lift is logged: the training max every
/// wave is prescribed from. Opens on 90% of the lifter's best e1RM when there
/// is history, and stands in for the set controls until answered.
struct TrainingMaxCard: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let exerciseIndex: Int

    @State private var oneRepMaxText = ""
    @State private var directTrainingMaxText = ""
    @State private var entersTrainingMaxDirectly = false
    @State private var isSaving = false

    private var exercise: ExerciseLogEntry? { viewModel.exercises[safe: exerciseIndex] }

    private var estimate: TrainingMaxService.OneRepMaxEstimate? {
        guard let exercise else { return nil }
        return viewModel.trainingMaxEstimates[exercise.exerciseId]
    }

    private var oneRepMax: Double? {
        Double(oneRepMaxText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var trainingMax: Double? {
        guard let exercise else { return nil }
        if entersTrainingMaxDirectly {
            return Double(directTrainingMaxText).flatMap { $0 > 0 ? $0 : nil }
        }
        return oneRepMax.map { WaveProgression.trainingMax(fromOneRepMax: $0, equipment: exercise.equipment) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(RQColors.accent)
                Text("TRAINING MAX")
                    .rqLabel()
                    .foregroundColor(RQColors.accent)
            }

            Text("Set your \(exercise?.exerciseName.lowercased() ?? "") training max")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)

            Text("5/3/1 runs off 90% of your max, not your max. Every set this cycle is a percentage of this number, and it only moves when a cycle ends.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if entersTrainingMaxDirectly {
                field(label: "TM", text: $directTrainingMaxText, caption: "the number your waves are taken from")
            } else {
                HStack(spacing: RQSpacing.md) {
                    field(
                        label: "1RM", text: $oneRepMaxText,
                        caption: estimate.map { "from your best set · \(format($0.weight)) × \($0.reps)" } ?? "your best single, or an estimate"
                    )
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("TM · 90%")
                            .rqLabel()
                            .foregroundColor(RQColors.accent)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(trainingMax.map(format) ?? "—")
                                .font(RQTypography.numbers)
                                .foregroundColor(trainingMax == nil ? RQColors.textTertiary : RQColors.textPrimary)
                            Text("lb")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Text("rounded to \(format(ProgressionService.weightIncrement(for: exercise?.equipment ?? "")))")
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RQSpacing.md)
                    .background(RQColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: RQRadius.medium, style: .continuous)
                            .stroke(RQColors.accent.opacity(0.5), lineWidth: 0.5)
                    )
                    .cornerRadius(RQRadius.medium)
                }
            }

            Button {
                withAnimation { entersTrainingMaxDirectly.toggle() }
            } label: {
                (Text(entersTrainingMaxDirectly ? "Have a 1RM instead? " : "Already know your TM? ")
                    .foregroundColor(RQColors.textSecondary)
                 + Text(entersTrainingMaxDirectly ? "Enter your 1RM" : "Enter it directly")
                    .foregroundColor(RQColors.accent)
                    .fontWeight(.semibold))
                    .font(RQTypography.caption)
            }
            .buttonStyle(.plain)

            Button {
                guard let trainingMax else { return }
                isSaving = true
                // "Estimated" only when the prefilled e1RM was accepted untouched.
                let acceptedEstimate = !entersTrainingMaxDirectly
                    && estimate.map { format($0.oneRepMax.rounded()) == oneRepMaxText } == true
                Task {
                    await viewModel.setTrainingMax(
                        exerciseIndex: exerciseIndex, value: trainingMax,
                        source: acceptedEstimate ? .estimated : .manual
                    )
                    isSaving = false
                }
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    if isSaving {
                        ProgressView().tint(RQColors.background)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(trainingMax.map { "Start \(WaveProgression.wave(at: waveIndex).name) week at TM \(format($0))" } ?? "Enter a max to start")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                .foregroundColor(RQColors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.lg)
                .background(RQColors.accent)
                .clipShape(Capsule())
                .opacity(trainingMax == nil || isSaving ? 0.35 : 1)
            }
            .disabled(trainingMax == nil || isSaving)
        }
        .padding(RQSpacing.lg)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                .stroke(RQColors.accent.opacity(0.35), lineWidth: 0.5)
        )
        .cornerRadius(RQRadius.large)
        .onAppear {
            if oneRepMaxText.isEmpty, let estimate {
                oneRepMaxText = format(estimate.oneRepMax.rounded())
            }
        }
    }

    private var waveIndex: Int {
        exercise?.progressionTarget?.programWeek ?? 0
    }

    private func field(label: String, text: Binding<String>, caption: String) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            Text(label)
                .rqLabel()
                .foregroundColor(RQColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)
                    .frame(maxWidth: 90)
                Text("lb")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
            Text(caption)
                .font(.system(size: 10))
                .foregroundColor(RQColors.textTertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RQSpacing.md)
        .background(RQColors.surfaceSecondary)
        .cornerRadius(RQRadius.medium)
    }

    private func format(_ weight: Double) -> String {
        WaveProgression.format(weight)
    }
}
