import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var workoutCoordinator = WorkoutCoordinator()
    @State private var activeWorkoutViewModel: ActiveWorkoutViewModel?
    @State private var socialViewModel = SocialViewModel()
    @State private var showRecoveryAlert = false
    @State private var recoveredState: SavedWorkoutState?

    var body: some View {
        @Bindable var coordinator = workoutCoordinator

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
        .fullScreenCover(isPresented: $coordinator.showActiveWorkout) {
            // Clean up when dismissed
            activeWorkoutViewModel = nil
        } content: {
            if recoveredState != nil {
                // Restoring from saved state — no template/day needed
                let vm = makeRecoveryViewModel()
                ActiveWorkoutView(viewModel: vm) {
                    workoutCoordinator.dismissWorkout()
                    recoveredState = nil
                }
                .environment(workoutCoordinator)
            } else if let template = workoutCoordinator.selectedTemplate,
               let day = workoutCoordinator.selectedWorkoutDay {
                let vm = makeWorkoutViewModel(template: template, day: day)
                ActiveWorkoutView(viewModel: vm) {
                    workoutCoordinator.dismissWorkout()
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
                    workoutCoordinator.showActiveWorkout = true
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
