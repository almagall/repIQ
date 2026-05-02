import AppIntents

/// Commits the upcoming working set on the active workout using whatever
/// pending weight / reps / RPE values the user has dialled in via the
/// stepper buttons (or the defaults pre-filled by `perSetTarget` if they
/// haven't adjusted anything).
///
/// Triggered by the LOG button on the Lock Screen and Dynamic Island.
struct LogSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var description = IntentDescription("Logs the next working set on your active workout.")

    init() {}

    func perform() async throws -> some IntentResult {
        try await WorkoutIntentBridge.shared.logSet()
        return .result()
    }
}
