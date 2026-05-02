import AppIntents

/// Which field of the upcoming set the stepper button is targeting.
enum SetField: String, AppEnum {
    case weight
    case reps
    case rpe

    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Set Field")

    static var caseDisplayRepresentations: [SetField: DisplayRepresentation] = [
        .weight: DisplayRepresentation(title: "Weight"),
        .reps: DisplayRepresentation(title: "Reps"),
        .rpe: DisplayRepresentation(title: "RPE")
    ]
}

/// Whether the stepper is bumping the field up or down by one increment.
enum AdjustDirection: String, AppEnum {
    case up
    case down

    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Adjust Direction")

    static var caseDisplayRepresentations: [AdjustDirection: DisplayRepresentation] = [
        .up: DisplayRepresentation(title: "Up"),
        .down: DisplayRepresentation(title: "Down")
    ]
}

/// Bumps weight, reps, or RPE on the upcoming set up or down by one
/// increment. Triggered by the −/+ buttons in the Lock Screen and Dynamic
/// Island steppers.
///
/// The intent mutates the active VM's SetEntry directly and pushes a Live
/// Activity update so the new value appears on the Lock Screen instantly.
/// The set is only persisted when the user taps LOG.
struct AdjustSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Set"
    static var description = IntentDescription("Adjusts weight, reps, or RPE on the upcoming set.")

    @Parameter(title: "Field")
    var field: SetField

    @Parameter(title: "Direction")
    var direction: AdjustDirection

    init() {
        self.field = .weight
        self.direction = .up
    }

    init(field: SetField, direction: AdjustDirection) {
        self.field = field
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        try await WorkoutIntentBridge.shared.adjustSet(field: field, direction: direction)
        return .result()
    }
}
