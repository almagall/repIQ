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

                // PR celebration overlay
                if let celebration = viewModel.prCelebration {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.prCelebration = nil
                            }
                        }

                    PRCelebrationView(celebration: celebration) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.prCelebration = nil
                        }
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                // Loading overlay
                if viewModel.isLoading && viewModel.exercises.isEmpty {
                    LoadingOverlay(message: "Starting workout...")
                }
            }
            .animation(.spring(response: 0.35), value: viewModel.prCelebration != nil)
            .background(RQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(viewModel.dayName)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)

                        HStack(spacing: RQSpacing.xs) {
                            Text(viewModel.elapsedDisplay)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)

                            if viewModel.isOffline {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 9))
                                    .foregroundColor(RQColors.warning)
                            }

                            if viewModel.hasPendingSets {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 9))
                                    Text("\(viewModel.pendingSetCount)")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(RQColors.warning)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
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
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        viewModel.showFinishConfirmation = true
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.success)
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
            // Workout progress bar
            if !viewModel.exercises.isEmpty {
                workoutProgressBar
            }

            // Proactive deload suggestion banner
            if let suggestion = viewModel.deloadSuggestion {
                deloadSuggestionBanner(suggestion)
            }

            // Exercise selector with integrated navigation + rest timer
            if !viewModel.exercises.isEmpty {
                exerciseSelector
            }

            // Exercise content — stacked for supersets, single for solo
            ScrollViewReader { proxy in
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

                        let groupIndices = viewModel.currentGroupIndices
                        let isSuperset = groupIndices.count > 1

                        // Superset header with round indicator
                        if isSuperset {
                            supersetHeader(groupIndices: groupIndices)
                        }

                        // Stacked exercise cards (or single for solo)
                        HStack(alignment: .top, spacing: RQSpacing.sm) {
                            // Gold bracket bar for supersets
                            if isSuperset {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(RQColors.supersetGold)
                                    .frame(width: 3)
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(groupIndices.enumerated()), id: \.element) { position, exerciseIdx in
                                    VStack(spacing: 0) {
                                        ExerciseLogView(
                                            viewModel: viewModel,
                                            exerciseIndex: exerciseIdx
                                        )
                                        .id(exerciseIdx)

                                        // Gold connector between superset exercises
                                        if isSuperset && position < groupIndices.count - 1 {
                                            supersetConnector
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.scrollToExerciseIndex) { _, newValue in
                    if let target = newValue {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        viewModel.scrollToExerciseIndex = nil
                    }
                }
            }
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
        VStack(spacing: 0) {
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
                            Text("\(viewModel.currentGroupPosition + 1)/\(viewModel.allGroups.count)")
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
                    }
                }

                // Rest timer pill
                Button {
                    viewModel.restTimerEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13))
                        if viewModel.restTimerEnabled {
                            Text(formattedRestDuration)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundColor(viewModel.restTimerEnabled ? RQColors.accent : RQColors.textTertiary.opacity(0.4))
                    .padding(.horizontal, RQSpacing.sm)
                    .padding(.vertical, 6)
                    .background(viewModel.restTimerEnabled ? RQColors.accent.opacity(0.15) : RQColors.surfaceTertiary.opacity(0.5))
                    .cornerRadius(RQRadius.large)
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
            .padding(.vertical, RQSpacing.xs)

            Divider().background(RQColors.surfaceTertiary.opacity(0.5))
        }
        .background(RQColors.background)
    }

    // MARK: - Superset Components

    private func supersetHeader(groupIndices: [Int]) -> some View {
        let groupLabel = supersetGroupLabel(for: groupIndices)
        let currentRound = viewModel.supersetCurrentRound(for: groupIndices)
        let totalRounds = viewModel.supersetTotalRounds(for: groupIndices)

        return HStack {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(RQColors.supersetGold)

            Text("SUPERSET \(groupLabel)")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(RQColors.supersetGold)

            Spacer()

            Text("Round \(currentRound) of \(totalRounds)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(RQColors.supersetGold)
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .background(RQColors.supersetGold.opacity(0.1))
        .cornerRadius(RQRadius.small)
    }

    private var supersetConnector: some View {
        HStack(spacing: RQSpacing.sm) {
            Rectangle()
                .fill(RQColors.supersetGold)
                .frame(width: 3, height: 20)

            Image(systemName: "arrow.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(RQColors.supersetGold)

            Text("no rest")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(RQColors.supersetGold.opacity(0.7))

            Spacer()
        }
        .padding(.leading, RQSpacing.md)
    }

    private func supersetGroupLabel(for groupIndices: [Int]) -> String {
        guard let firstIdx = groupIndices.first,
              let group = viewModel.exercises[safe: firstIdx]?.supersetGroup else { return "" }
        let labels = ["A", "B", "C", "D", "E"]
        return labels[safe: group] ?? "\(group + 1)"
    }

    // MARK: - Workout Progress Bar

    private var workoutProgressBar: some View {
        let totalExercises = viewModel.exercises.count
        let completedExercises = viewModel.exercises.filter(\.isAllSetsCompleted).count
        let progress = totalExercises > 0 ? Double(completedExercises) / Double(totalExercises) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RQColors.surfaceTertiary.opacity(0.5))

                Rectangle()
                    .fill(RQColors.accent)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 3)
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

