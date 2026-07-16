import SwiftUI
import Supabase

struct MainTabView: View {
    let workoutCoordinator: WorkoutCoordinator

    @State private var selectedTab = 0
    @State private var showRecoveryAlert = false
    @State private var recoveredState: SavedWorkoutState?
    @State private var unviewedWrappedCount: Int = 0

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
                .badge(unviewedWrappedCount)
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
            await refreshWrappedBadge()
        }
        .onChange(of: selectedTab) { _, newTab in
            // When the user lands on Progress, the wrapped will be marked viewed
            // by MonthlyWrappedView itself; refresh the badge after a brief delay.
            if newTab == 1 {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await refreshWrappedBadge()
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

    /// Pulls the prior month's wrapped status to drive the Progress-tab dot
    /// badge. Shows a "1" until the user views (or dismisses) the wrapped.
    private func refreshWrappedBadge() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            unviewedWrappedCount = 0
            return
        }
        let wrapped = try? await DigestService().fetchPriorMonthWrapped(userId: userId)
        unviewedWrappedCount = (wrapped?.viewedAt == nil && wrapped != nil) ? 1 : 0
    }
}
