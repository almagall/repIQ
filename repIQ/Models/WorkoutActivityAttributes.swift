import ActivityKit
import Foundation

/// Live Activity data model. Defines what's pushed to the Lock Screen and
/// Dynamic Island while a workout is in progress.
///
/// Static `attributes` (set once when the activity starts):
///   - `workoutName`: e.g. "PPL · Push A"
///   - `startedAt`: when the workout began (used for elapsed-time rendering)
///
/// Dynamic `ContentState` (updated on meaningful events — set complete, exercise
/// change, rest start/end). We avoid pushing on every second tick because
/// Apple's Live Activity update budget is limited; instead the layout uses
/// `Text(timerInterval:)` to render live countdowns client-side.
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentExerciseName: String
        var setProgress: String              // e.g. "Set 3/4"
        var elapsedSeconds: Int              // total workout elapsed (for fallback display)
        var restEndDate: Date?               // nil when no rest is running
        var isRestActive: Bool               // convenience flag for layout decisions
    }

    var workoutName: String
    var startedAt: Date
}
