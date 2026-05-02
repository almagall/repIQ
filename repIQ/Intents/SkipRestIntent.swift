import AppIntents

/// Cancels the running rest timer. Triggered from a Lock Screen button
/// during rest.
struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description = IntentDescription("Skips the running rest timer in your active workout.")

    init() {}

    func perform() async throws -> some IntentResult {
        try await WorkoutIntentBridge.shared.skipRest()
        return .result()
    }
}
