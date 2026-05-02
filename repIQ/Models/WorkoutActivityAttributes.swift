import ActivityKit
import Foundation

/// Live Activity data model. Defines what's pushed to the Lock Screen and
/// Dynamic Island while a workout is in progress.
///
/// Static `attributes` (set once when the activity starts):
///   - `workoutName`: e.g. "PPL · Push A"
///   - `startedAt`: when the workout began (used for elapsed-time rendering)
///
/// Dynamic `ContentState` (updated on meaningful events — set complete,
/// exercise change, rest start/end, stepper tap). We avoid pushing on every
/// second tick because Apple's Live Activity update budget is limited;
/// instead the layout uses `Text(timerInterval:)` to render live countdowns
/// client-side.
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Display strings (compact / minimal fallbacks)
        var currentExerciseName: String
        var setProgress: String              // e.g. "Set 3/4"
        var elapsedSeconds: Int              // total workout elapsed
        var restEndDate: Date?               // nil when no rest is running
        var isRestActive: Bool

        // Pending values for the upcoming set — adjusted via stepper buttons,
        // committed by the LOG button. Mirrors the active VM's SetEntry, so
        // what's shown is what gets saved.
        var pendingWeight: Double?           // nil for bodyweight
        var pendingReps: Int
        var pendingRPE: Double?              // nil = "—"

        // Frozen suggested target (from `perSetTarget` at workout start).
        // Shown as the "Goal" line so the user sees what their program
        // prescribes even after they've adjusted the pending values.
        var goalWeight: Double?
        var goalReps: Int
        var goalRPE: Double?

        // What the user did on this set number in their most recent prior
        // session for the same exercise + workout day. Drives the "Last"
        // line.
        var previousSet: PreviousSetSummary?

        var weightStep: Double               // per-equipment increment
        var weightUnit: String               // "lb" or "kg"

        // Indices the intents use to address the upcoming set.
        var currentExerciseIndex: Int
        var currentSetIndex: Int

        // Drives whether stepper UI is shown. Working sets get the steppers
        // + LOG; warmup / cooldown / no-upcoming show a placeholder.
        var setKind: SetKind
    }

    var workoutName: String
    var startedAt: Date

    enum SetKind: String, Codable, Hashable {
        case warmup
        case working
        case other   // cooldown / drop / failure / no upcoming set
    }

    struct PreviousSetSummary: Codable, Hashable {
        var weight: Double?  // nil for bodyweight
        var reps: Int
        var rpe: Double?
    }
}
