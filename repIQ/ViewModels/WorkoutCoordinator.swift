import Foundation

@Observable
final class WorkoutCoordinator {
    var showActiveWorkout = false
    var selectedTemplate: Template?
    var selectedWorkoutDay: WorkoutDay?
    var selectedWorkoutDate: Date?

    /// Called from TemplateDetailView or Dashboard to start a workout.
    func startWorkout(template: Template, day: WorkoutDay, date: Date) {
        selectedTemplate = template
        selectedWorkoutDay = day
        selectedWorkoutDate = date
        showActiveWorkout = true
    }

    /// Called when the workout is dismissed (completed or abandoned).
    func dismissWorkout() {
        showActiveWorkout = false
        selectedTemplate = nil
        selectedWorkoutDay = nil
        selectedWorkoutDate = nil
    }
}
