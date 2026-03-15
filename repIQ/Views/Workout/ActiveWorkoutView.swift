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
                    HStack(spacing: RQSpacing.sm) {
                        // Elapsed timer — passive display, no icon
                        Text(viewModel.elapsedDisplay)
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.textSecondary)

                        // Offline indicator
                        if viewModel.isOffline {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.warning)
                        }

                        // Pending sync indicator
                        if viewModel.hasPendingSets {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                                Text("\(viewModel.pendingSetCount)")
                                    .font(RQTypography.caption)
                            }
                            .foregroundColor(RQColors.warning)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: RQSpacing.lg) {
                        // Overflow menu (abandon lives here)
                        Menu {
                            Button(role: .destructive) {
                                viewModel.showAbandonConfirmation = true
                            } label: {
                                Label("Abandon Workout", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(RQColors.textSecondary)
                        }

                        // Finish button
                        Button("Finish") {
                            viewModel.showFinishConfirmation = true
                        }
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.success)
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
            .sheet(isPresented: $viewModel.showExerciseSubstitution) {
                if let exercise = viewModel.currentExercise {
                    ExerciseSubstitutionView(currentExercise: exercise) { newExercise in
                        Task {
                            await viewModel.substituteExercise(
                                at: viewModel.currentExerciseIndex,
                                with: newExercise
                            )
                        }
                    }
                }
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
            // Proactive deload suggestion banner
            if let suggestion = viewModel.deloadSuggestion {
                deloadSuggestionBanner(suggestion)
            }

            // Exercise selector with integrated navigation
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
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Deload Suggestion Banner

    private func deloadSuggestionBanner(_ suggestion: ProgressionService.DeloadSuggestion) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(RQColors.accent)

                Text("Consider a Deload Week")
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Spacer()

                Button {
                    withAnimation { viewModel.dismissDeloadSuggestion() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 24, height: 24)
                }
            }

            Text("You've completed \(suggestion.sessionCount) sessions in the last 5 weeks\(suggestion.weeksSinceLastDeload.map { " (\($0)+ weeks since last deload)" } ?? "") without a deload. A lighter week can help recovery and long-term strength gains.")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textSecondary)

            HStack(spacing: RQSpacing.md) {
                Button {
                    withAnimation { viewModel.dismissDeloadSuggestion() }
                } label: {
                    Text("Dismiss")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textSecondary)
                        .padding(.horizontal, RQSpacing.lg)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.surfaceTertiary)
                        .cornerRadius(RQRadius.medium)
                }

                Button {
                    withAnimation { viewModel.applyDeloadToAllExercises() }
                } label: {
                    Text("Apply Deload")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .padding(.horizontal, RQSpacing.lg)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                }
            }
        }
        .padding(RQSpacing.md)
        .background(RQColors.accent.opacity(0.08))
        .cornerRadius(RQRadius.large)
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.top, RQSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Exercise Selector with Navigation

    private var exerciseSelector: some View {
        HStack(spacing: RQSpacing.sm) {
            // Previous button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.goToPreviousExercise()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.canGoToPrevious ? RQColors.accent : RQColors.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            .disabled(!viewModel.canGoToPrevious)

            // Exercise dropdown
            Menu {
                ForEach(viewModel.exercises.indices, id: \.self) { index in
                    let exercise = viewModel.exercises[index]
                    Button {
                        viewModel.goToExercise(at: index)
                    } label: {
                        HStack {
                            if exercise.supersetGroup != nil {
                                Image(systemName: "link")
                            }
                            Text(exercise.exerciseName)
                            if exercise.isSubstituted {
                                Image(systemName: "arrow.triangle.swap")
                            }
                            if exercise.isAllSetsCompleted {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    if let exercise = viewModel.currentExercise {
                        // Exercise counter badge
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Spacer()

                    // Overall progress
                    let completed = viewModel.exercises.filter(\.isAllSetsCompleted).count
                    if completed > 0 {
                        Text("\(completed) done")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(RQColors.success)
                    }
                }
            }

            // Next button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.goToNextExercise()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.canGoToNext ? RQColors.accent : RQColors.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            .disabled(!viewModel.canGoToNext)
        }
        .padding(.horizontal, RQSpacing.sm)
        .padding(.vertical, RQSpacing.sm)
        .background(RQColors.background)
    }

    // MARK: - Rest Timer Settings

    private var restTimerSettingsBar: some View {
        HStack(spacing: RQSpacing.md) {
            // Toggle pill
            Button {
                viewModel.restTimerEnabled.toggle()
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: viewModel.restTimerEnabled ? "timer" : "timer.slash")
                        .font(.system(size: 13))

                    Text("Rest")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)

                    Text(viewModel.restTimerEnabled ? "ON" : "OFF")
                        .font(RQTypography.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(viewModel.restTimerEnabled ? RQColors.accent : RQColors.textTertiary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(viewModel.restTimerEnabled ? RQColors.accent.opacity(0.15) : RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.large)
            }

            // Duration controls (only when enabled)
            if viewModel.restTimerEnabled {
                // Decrease
                Button {
                    viewModel.adjustRestTimerDuration(by: -15)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RQColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }

                Text(formattedRestDuration)
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)
                    .frame(minWidth: 40)

                // Increase
                Button {
                    viewModel.adjustRestTimerDuration(by: 15)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RQColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }
            }

            Spacer()
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.vertical, RQSpacing.xs)
        .background(RQColors.background)
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

