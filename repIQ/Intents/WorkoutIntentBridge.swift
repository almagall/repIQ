import Foundation

/// Bridge between Live Activity / Siri intents and the running workout.
///
/// `LiveActivityIntent.perform()` runs in the host app's main process. It
/// can't reach into the main-app's heavy types (`ActiveWorkoutViewModel`,
/// `WorkoutCoordinator`) directly because the same intent file is also
/// compiled into the widget extension target, which doesn't have those
/// types. So the intent calls into this lightweight bridge instead, and
/// the main app registers handlers when a workout is active.
///
/// When no workout is active (or the app was force-quit and just
/// re-launched in response to an intent before the user has resumed the
/// session), the handlers are nil and the bridge throws
/// `WorkoutIntentError.noActiveWorkout`.
@MainActor
final class WorkoutIntentBridge {
    static let shared = WorkoutIntentBridge()
    private init() {}

    /// Commits the upcoming working set with whatever pending values are on
    /// the active VM's SetEntry.
    var logSetHandler: (() async throws -> Void)?

    /// Bumps the chosen field on the upcoming set up or down by one
    /// increment, then pushes a Live Activity update.
    var adjustSetHandler: ((SetField, AdjustDirection) async throws -> Void)?

    /// Cancels the running rest timer.
    var skipRestHandler: (() async throws -> Void)?

    func logSet() async throws {
        guard let handler = logSetHandler else {
            throw WorkoutIntentError.noActiveWorkout
        }
        try await handler()
    }

    func adjustSet(field: SetField, direction: AdjustDirection) async throws {
        guard let handler = adjustSetHandler else {
            throw WorkoutIntentError.noActiveWorkout
        }
        try await handler(field, direction)
    }

    func skipRest() async throws {
        guard let handler = skipRestHandler else {
            throw WorkoutIntentError.noActiveWorkout
        }
        try await handler()
    }
}

enum WorkoutIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveWorkout
    case noUpcomingSet
    case missingTarget

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveWorkout:
            return "Open repIQ to continue your workout."
        case .noUpcomingSet:
            return "No upcoming working set to log."
        case .missingTarget:
            return "Open repIQ to enter weight first."
        }
    }
}
