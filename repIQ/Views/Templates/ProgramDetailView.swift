import SwiftUI

struct ProgramDetailView: View {
    let program: ProgramDefinition
    var onProgramCreated: () -> Void = {}
    @State private var viewModel = ProgramBrowserViewModel()
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Program header
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text(program.name)
                            .font(RQTypography.title2)
                            .foregroundColor(RQColors.textPrimary)

                        Text(program.description)
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.textSecondary)

                        HStack(spacing: RQSpacing.md) {
                            statItem(value: "\(program.daysPerWeek)", label: "DAYS/WK")
                            statItem(value: program.difficulty.displayName, label: "LEVEL")
                            statItem(value: "\(totalExerciseCount)", label: "EXERCISES")
                        }
                    }
                }

                // Workout days
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    Text("Workout Days")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)

                    ForEach(program.days) { day in
                        dayCard(day)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: RQSpacing.xs) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.error)
                }

                RQButton(
                    title: "Use This Program",
                    isLoading: viewModel.isMaterializing
                ) {
                    Task {
                        await viewModel.materializeProgram(program)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.md)
            .padding(.bottom, RQSpacing.sm)
            .background(RQColors.background)
        }
        .background(RQColors.background)
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay {
            if showSuccess {
                successOverlay
                    .transition(.opacity)
            }
        }
        .onChange(of: viewModel.materializedTemplate != nil) {
            if viewModel.materializedTemplate != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onProgramCreated()
                }
            }
        }
    }

    private var totalExerciseCount: Int {
        Set(program.days.flatMap { $0.exercises.map(\.exerciseName) }).count
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(value)
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(RQTypography.label)
                .tracking(1)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var successOverlay: some View {
        ZStack {
            RQColors.background.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: RQSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(RQColors.success)

                VStack(spacing: RQSpacing.xs) {
                    Text("Program Added!")
                        .font(RQTypography.title2)
                        .foregroundColor(RQColors.textPrimary)

                    Text(program.name)
                        .font(RQTypography.subheadline)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private func dayCard(_ day: ProgramDayDefinition) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(day.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    if !day.description.isEmpty {
                        Text(day.description)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                ForEach(day.exercises) { exercise in
                    HStack(spacing: RQSpacing.md) {
                        // Mode indicator bar
                        RoundedRectangle(cornerRadius: 1)
                            .fill(exercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(exercise.exerciseName)
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                            HStack(spacing: RQSpacing.sm) {
                                Text("\(exercise.targetSets) sets")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                Text("\u{00B7}")
                                    .foregroundColor(RQColors.textTertiary)
                                Text(exercise.trainingMode.displayName)
                                    .font(RQTypography.caption)
                                    .foregroundColor(
                                        exercise.trainingMode == .hypertrophy
                                            ? RQColors.hypertrophy
                                            : RQColors.strength
                                    )
                                let range = exercise.trainingMode.repRange
                                Text("(\(range.lowerBound)-\(range.upperBound) reps)")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
