import AppIntents

/// Logs the next un-completed working set with values supplied by voice.
///
/// Distinct from `LogSetIntent`, which commits whatever values are dialed in
/// on the Live Activity steppers. This one is parameterized so Siri can
/// fill the values directly from natural speech:
///   "Hey Siri, log 225 for 8 RPE 7."
///   "Hey Siri, log 185 for 10 in repIQ."
///
/// Lives in the main app target only — Siri/AppShortcuts aren't relevant in
/// the widget extension.
struct LogSetByVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Set"
    static var description = IntentDescription(
        "Logs the next working set on your active workout with the weight, reps, and optional RPE you say.",
        categoryName: "Workouts"
    )

    /// Keep the user in their headphones / on the lock screen instead of
    /// yanking them into the app. The handler updates the Live Activity so
    /// the new set appears there immediately.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Weight", description: "How much weight you lifted.")
    var weight: Double

    @Parameter(title: "Reps", description: "How many reps you completed.")
    var reps: Int

    @Parameter(title: "RPE", description: "Rate of perceived exertion, 1 to 10.")
    var rpe: Double?

    init() {}

    init(weight: Double, reps: Int, rpe: Double? = nil) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Clamp RPE into the valid range. Siri occasionally hands back values
        // outside 1–10 from edge phrasings ("RPE eleven"); silently clamping
        // beats throwing.
        let clampedRPE: Double? = rpe.map { min(max($0, 1), 10) }

        try await WorkoutIntentBridge.shared.logSetWithValues(
            weight: weight,
            reps: reps,
            rpe: clampedRPE
        )

        return .result(dialog: IntentDialog(stringLiteral: confirmationPhrase(rpe: clampedRPE)))
    }

    private func confirmationPhrase(rpe: Double?) -> String {
        let weightStr = formatNumber(weight)
        if let rpe {
            return "Logged \(weightStr) for \(reps) at RPE \(formatNumber(rpe))."
        }
        return "Logged \(weightStr) for \(reps)."
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
