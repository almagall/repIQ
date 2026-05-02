import Foundation

/// Tracks how the active workout is being presented to the user.
/// - `hidden`: no workout in progress
/// - `minimized`: workout is in progress but user is navigating other parts of the app;
///   a persistent mini-bar above the tab bar shows essential info (timer, current exercise,
///   rest countdown) and tapping it expands back to the full workout
/// - `expanded`: full-screen workout view is presented
enum WorkoutPresentation: Equatable {
    case hidden
    case minimized
    case expanded
}

@Observable
final class WorkoutCoordinator {
    /// The most recently created coordinator. App Intents (run from Live
    /// Activity buttons / Siri) use this to reach the in-flight workout.
    /// `RootView` creates exactly one coordinator per app session, so this
    /// reference is unambiguous while the app is alive.
    static private(set) weak var current: WorkoutCoordinator?

    var presentation: WorkoutPresentation = .hidden
    var selectedTemplate: Template?
    var selectedWorkoutDay: WorkoutDay?
    var selectedWorkoutDate: Date?

    /// The view model backing the active workout. Owned here (rather than in a
    /// SwiftUI `@State`/`@Binding`) so it survives across `expanded ↔ minimized`
    /// transitions without relying on SwiftUI re-evaluating a body closure to
    /// keep the reference alive.
    var activeViewModel: ActiveWorkoutViewModel?

    init() {
        Self.current = self
    }

    /// Whether a workout is currently active (either minimized or expanded).
    /// Used to decide whether the mini-bar / view model should be alive.
    var isActive: Bool { presentation != .hidden }

    /// Convenience for the full-screen cover binding in MainTabView.
    var isExpanded: Bool { presentation == .expanded }

    /// Whether the mini-bar should be visible above the tab bar.
    var isMinimized: Bool { presentation == .minimized }

    /// Called from TemplateDetailView or Dashboard to start a workout.
    func startWorkout(template: Template, day: WorkoutDay, date: Date) {
        selectedTemplate = template
        selectedWorkoutDay = day
        selectedWorkoutDate = date
        if activeViewModel == nil {
            activeViewModel = ActiveWorkoutViewModel()
        }
        presentation = .expanded
    }

    /// Resumes a workout that was force-quit. Creates the view model, restores
    /// its state from disk, and re-arms autosave before expanding.
    func startRecoveredWorkout(state: SavedWorkoutState) {
        if activeViewModel == nil {
            let vm = ActiveWorkoutViewModel()
            vm.restoreFromSavedState(state)
            vm.startAutoSavePublic()
            activeViewModel = vm
        }
        presentation = .expanded
    }

    /// Collapses the expanded workout to a mini-bar so the user can navigate the
    /// rest of the app while the workout is still active. View model state is
    /// preserved (lives on this coordinator) and reused on expand.
    func minimize() {
        guard presentation == .expanded else { return }
        presentation = .minimized
    }

    /// Re-expands the minimized workout to the full-screen view.
    func expand() {
        guard presentation == .minimized else { return }
        presentation = .expanded
    }

    /// Called when the workout is finished or abandoned. Tears down all state.
    func dismissWorkout() {
        presentation = .hidden
        selectedTemplate = nil
        selectedWorkoutDay = nil
        selectedWorkoutDate = nil
        activeViewModel = nil
    }
}
