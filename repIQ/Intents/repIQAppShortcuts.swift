import AppIntents

/// Bundles the user-facing voice shortcuts Siri auto-discovers for repIQ.
/// Phrases must include `\(.applicationName)` somewhere.
///
/// **System constraints we work around:**
/// - At most one parameter slot per phrase.
/// - Parameter slots in phrases must be `AppEntity` or `AppEnum`; primitive
///   types (Double, Int, String) aren't allowed.
///
/// Together those rule out a one-liner like "log 225 for 8 RPE 7" inside an
/// auto-discovered phrase. We use bare phrasings here, and Siri's parameter
/// resolution flow prompts for each value in turn ("How much weight?" "How
/// many reps?" "What was the RPE?"). Power users who want one-shot dictation
/// can build a custom Shortcut on top of `LogSetByVoiceIntent` in the
/// Shortcuts app — that flow accepts all three parameters in a single phrase.
struct repIQAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSetByVoiceIntent(),
            phrases: [
                "Log a set in \(.applicationName)",
                "Log set in \(.applicationName)",
                "Add a set in \(.applicationName)",
                "Log my set in \(.applicationName)",
                "Record a set in \(.applicationName)"
            ],
            shortTitle: "Log a Set",
            systemImageName: "dumbbell.fill"
        )
    }
}
