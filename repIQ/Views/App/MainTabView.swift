import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var workoutCoordinator = WorkoutCoordinator()
    @State private var activeWorkoutViewModel: ActiveWorkoutViewModel?
    @State private var socialViewModel = SocialViewModel()
    @State private var showRecoveryAlert = false
    @State private var recoveredState: SavedWorkoutState?

    /// Binding for the full-screen cover. Reads `coordinator.isExpanded`.
    /// On dismiss (set to false), the cover becomes hidden — but if the workout is
    /// still active (just minimized), we DON'T tear down the view model.
    private var expandedBinding: Binding<Bool> {
        Binding(
            get: { workoutCoordinator.isExpanded },
            set: { newValue in
                if !newValue && workoutCoordinator.isExpanded {
                    // System or programmatic dismiss — collapse rather than fully end
                    workoutCoordinator.minimize()
                }
            }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 1) {
                ProgressTabView()
            }

            Tab("Social", systemImage: "person.2.fill", value: 2) {
                SocialTabView(viewModel: socialViewModel)
            }
            .badge(socialViewModel.notificationCount)

            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(RQColors.accent)
        .environment(workoutCoordinator)
        // Mini-bar appears above the tab bar when a workout is minimized.
        // safeAreaInset reserves space so tab content isn't hidden behind it.
        .safeAreaInset(edge: .bottom) {
            if workoutCoordinator.isMinimized, let vm = activeWorkoutViewModel {
                WorkoutMiniBar(viewModel: vm) {
                    workoutCoordinator.expand()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: workoutCoordinator.isMinimized)
        .fullScreenCover(isPresented: expandedBinding) {
            if recoveredState != nil {
                // Restoring from saved state — no template/day needed
                let vm = makeRecoveryViewModel()
                ActiveWorkoutView(viewModel: vm) {
                    // Full dismiss path (Finish / Abandon)
                    workoutCoordinator.dismissWorkout()
                    activeWorkoutViewModel = nil
                    recoveredState = nil
                }
                .environment(workoutCoordinator)
            } else if let template = workoutCoordinator.selectedTemplate,
               let day = workoutCoordinator.selectedWorkoutDay {
                let vm = makeWorkoutViewModel(template: template, day: day)
                ActiveWorkoutView(viewModel: vm) {
                    // Full dismiss path (Finish / Abandon)
                    workoutCoordinator.dismissWorkout()
                    activeWorkoutViewModel = nil
                }
                .environment(workoutCoordinator)
            }
        }
        .task {
            // Check for recoverable workout on app launch
            if WorkoutAutoSave.hasRecoverableState,
               let state = WorkoutAutoSave.load() {
                // Only recover if saved less than 4 hours ago
                if Date().timeIntervalSince(state.savedAt) < 4 * 3600 {
                    recoveredState = state
                    showRecoveryAlert = true
                } else {
                    WorkoutAutoSave.clear()
                }
            }
        }
        .alert("Resume Workout?", isPresented: $showRecoveryAlert) {
            Button("Resume") {
                if recoveredState != nil {
                    workoutCoordinator.presentation = .expanded
                }
            }
            Button("Discard", role: .destructive) {
                recoveredState = nil
                WorkoutAutoSave.clear()
            }
        } message: {
            if let state = recoveredState {
                Text("You have an unfinished \(state.dayName.isEmpty ? "workout" : state.dayName) from \(state.savedAt.relativeDisplay). Would you like to pick up where you left off?")
            }
        }
    }

    private func makeWorkoutViewModel(template: Template, day: WorkoutDay) -> ActiveWorkoutViewModel {
        if let existing = activeWorkoutViewModel {
            return existing
        }
        let vm = ActiveWorkoutViewModel()
        activeWorkoutViewModel = vm
        return vm
    }

    private func makeRecoveryViewModel() -> ActiveWorkoutViewModel {
        if let existing = activeWorkoutViewModel {
            return existing
        }
        let vm = ActiveWorkoutViewModel()
        if let state = recoveredState {
            vm.restoreFromSavedState(state)
            vm.startAutoSavePublic()
        }
        activeWorkoutViewModel = vm
        return vm
    }
}
