import SwiftUI

struct MainTabView: View {
    let workoutCoordinator: WorkoutCoordinator

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
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

    /// Reusable modifier that wraps a tab's content with the mini-bar.
    @ViewBuilder
    private func withMiniBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if workoutCoordinator.isMinimized, let vm = workoutCoordinator.activeViewModel {
                    WorkoutMiniBar(viewModel: vm) {
                        workoutCoordinator.expand()
                    }
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: workoutCoordinator.isMinimized)
    }

    var body: some View {
        // Use the legacy `.tabItem` API; mini-bar is added via safeAreaInset on
        // each tab's root content view (see `withMiniBar`).
        TabView(selection: $selectedTab) {
            withMiniBar { DashboardView() }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            withMiniBar { ProgressTabView() }
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            withMiniBar { ProfileView() }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(RQColors.accent)
        .environment(workoutCoordinator)
        .fullScreenCover(isPresented: expandedBinding) {
            if let vm = workoutCoordinator.activeViewModel {
                ActiveWorkoutView(viewModel: vm) {
                    // Full dismiss path (Finish / Abandon)
                    workoutCoordinator.dismissWorkout()
                    recoveredState = nil
                }
                .environment(workoutCoordinator)
            }
        }
        // Observed here rather than in ActiveWorkoutView: the cover leaves the
        // hierarchy when the workout is minimized, so a backgrounded mini-bar
        // workout would otherwise only be as fresh as the last 30s autosave tick.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                workoutCoordinator.activeViewModel?.saveWorkoutState()
            }
        }
        .task {
            // Check for recoverable workout on app launch
            if WorkoutAutoSave.hasRecoverableState,
               let state = WorkoutAutoSave.load() {
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
                if let state = recoveredState {
                    workoutCoordinator.startRecoveredWorkout(state: state)
                    recoveredState = nil
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
}
