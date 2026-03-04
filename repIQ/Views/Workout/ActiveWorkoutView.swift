import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    let onDismiss: () -> Void

    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                // Main workout content
                workoutContent

                // Rest timer overlay
                if viewModel.restTimerActive {
                    RestTimerView(viewModel: viewModel)
                        .transition(.opacity)
                }

                // Loading overlay
                if viewModel.isLoading && viewModel.exercises.isEmpty {
                    LoadingOverlay(message: "Starting workout...")
                }
            }
            .background(RQColors.background)
            .navigationTitle(viewModel.dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Elapsed timer
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                        Text(viewModel.elapsedDisplay)
                            .font(RQTypography.numbersSmall)
                    }
                    .foregroundColor(RQColors.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        viewModel.showFinishConfirmation = true
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.success)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                        .foregroundColor(RQColors.accent)
                    }
                }
            }
            .alert("Finish Workout?", isPresented: $viewModel.showFinishConfirmation) {
                Button("Finish", role: .none) {
                    Task { await viewModel.completeWorkout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(viewModel.totalCompletedSets) sets completed · \(formattedVolume) total volume")
            }
            .alert("Abandon Workout?", isPresented: $viewModel.showAbandonConfirmation) {
                Button("Abandon", role: .destructive) {
                    Task {
                        await viewModel.abandonWorkout()
                        onDismiss()
                    }
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your logged sets will be saved, but the session will be marked as abandoned.")
            }
            .fullScreenCover(item: summaryBinding) { summary in
                WorkoutSummaryView(summary: summary) {
                    onDismiss()
                }
            }
            .task {
                if let template = coordinator.selectedTemplate,
                   let day = coordinator.selectedWorkoutDay {
                    let date = coordinator.selectedWorkoutDate ?? Date()
                    await viewModel.startWorkout(template: template, day: day, date: date)
                }
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Workout Content

    @ViewBuilder
    private var workoutContent: some View {
        VStack(spacing: 0) {
            // Exercise selector dropdown
            if !viewModel.exercises.isEmpty {
                exerciseSelector
            }

            // Rest timer settings
            restTimerSettingsBar

            // Current exercise
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(RQTypography.footnote)
                            .foregroundColor(RQColors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, RQSpacing.md)
                    }

                    // Single exercise card
                    ExerciseLogView(
                        viewModel: viewModel,
                        exerciseIndex: viewModel.currentExerciseIndex
                    )

                    // Abandon workout button
                    Button {
                        viewModel.showAbandonConfirmation = true
                    } label: {
                        Text("Abandon Workout")
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.error)
                    }
                    .padding(.top, RQSpacing.lg)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }

            // Previous / Next navigation bar
            if !viewModel.exercises.isEmpty {
                exerciseNavigationBar
            }
        }
    }

    // MARK: - Exercise Selector Dropdown

    private var exerciseSelector: some View {
        Menu {
            ForEach(viewModel.exercises.indices, id: \.self) { index in
                let exercise = viewModel.exercises[index]
                Button {
                    viewModel.goToExercise(at: index)
                } label: {
                    HStack {
                        Text(exercise.exerciseName)
                        if exercise.isAllSetsCompleted {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: RQSpacing.sm) {
                if let exercise = viewModel.currentExercise {
                    // Exercise counter
                    Text("\(viewModel.currentExerciseIndex + 1)/\(viewModel.exercises.count)")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .padding(.horizontal, RQSpacing.sm)
                        .padding(.vertical, RQSpacing.xxs)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.small)

                    Text(exercise.exerciseName)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                // Overall progress
                let completed = viewModel.exercises.filter(\.isAllSetsCompleted).count
                if completed > 0 {
                    Text("\(completed) done")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.success)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.md)
            .background(RQColors.surfacePrimary)
        }
    }

    // MARK: - Navigation Bar

    private var exerciseNavigationBar: some View {
        HStack(spacing: RQSpacing.md) {
            // Previous button
            if viewModel.canGoToPrevious {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.goToPreviousExercise()
                    }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Previous")
                            .font(RQTypography.subheadline)
                    }
                    .foregroundColor(RQColors.accent)
                    .padding(.vertical, RQSpacing.md)
                }
            }

            Spacer()

            // Next button
            if viewModel.canGoToNext {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.goToNextExercise()
                    }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Text("Next")
                            .font(RQTypography.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(RQColors.accent)
                    .padding(.vertical, RQSpacing.md)
                }
            }
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.bottom, RQSpacing.sm)
        .background(RQColors.surfacePrimary)
    }

    // MARK: - Rest Timer Settings

    private var restTimerSettingsBar: some View {
        HStack(spacing: RQSpacing.sm) {
            // Toggle
            Button {
                viewModel.restTimerEnabled.toggle()
            } label: {
                HStack(spacing: RQSpacing.xs) {
                    Image(systemName: viewModel.restTimerEnabled ? "timer" : "timer.slash")
                        .font(.system(size: 14))
                    Text("Rest")
                        .font(RQTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(viewModel.restTimerEnabled ? RQColors.accent : RQColors.textTertiary)
            }

            if viewModel.restTimerEnabled {
                Spacer()

                // Decrease duration
                Button {
                    viewModel.adjustRestTimerDuration(by: -15)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RQColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }

                // Duration display
                Text(formattedRestDuration)
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)
                    .frame(minWidth: 44)

                // Increase duration
                Button {
                    viewModel.adjustRestTimerDuration(by: 15)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RQColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }
            } else {
                Spacer()

                Text("Off")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.vertical, RQSpacing.sm)
        .background(RQColors.surfacePrimary)
    }

    // MARK: - Helpers

    private var formattedRestDuration: String {
        let minutes = viewModel.restTimerDuration / 60
        let seconds = viewModel.restTimerDuration % 60
        if minutes > 0 && seconds == 0 {
            return "\(minutes)m"
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)s"
    }

    private var formattedVolume: String {
        let volume = viewModel.totalVolume
        if volume >= 1000 {
            return String(format: "%.0fk lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }

    private var summaryBinding: Binding<WorkoutSummaryData?> {
        Binding(
            get: { viewModel.workoutSummary },
            set: { viewModel.workoutSummary = $0 }
        )
    }
}

// Make WorkoutSummaryData identifiable for .fullScreenCover(item:)
extension WorkoutSummaryData: @retroactive Identifiable {
    var id: Int { duration.hashValue ^ totalSets.hashValue }
}
