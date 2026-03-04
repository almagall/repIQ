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
                    await viewModel.startWorkout(template: template, day: day)
                }
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Workout Content

    @ViewBuilder
    private var workoutContent: some View {
        ScrollView {
            LazyVStack(spacing: RQSpacing.lg) {
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RQSpacing.md)
                }

                // Exercise cards
                ForEach(viewModel.exercises.indices, id: \.self) { index in
                    ExerciseLogView(
                        viewModel: viewModel,
                        exerciseIndex: index
                    )
                }

                // Abandon workout button
                if !viewModel.exercises.isEmpty {
                    Button {
                        viewModel.showAbandonConfirmation = true
                    } label: {
                        Text("Abandon Workout")
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.error)
                    }
                    .padding(.top, RQSpacing.lg)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
    }

    // MARK: - Helpers

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
