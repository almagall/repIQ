import ActivityKit
import Foundation

/// Singleton wrapper around ActivityKit for the workout Live Activity.
/// Lifetime of the active `Activity` reference outlives any single view, so
/// updates from anywhere in the app reach the same Lock Screen / Dynamic Island.
///
/// Silently no-ops if the user has Live Activities disabled in Settings.
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private var activity: Activity<WorkoutActivityAttributes>?

    /// Whether the system + user have Live Activities enabled.
    private var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    /// Begins a new Live Activity for the workout. If one is already running,
    /// it is ended first to avoid orphaned activities.
    func start(workoutName: String, startedAt: Date, initialState: WorkoutActivityAttributes.ContentState) {
        guard isAvailable else { return }

        // End any leftover activity from a previous workout that wasn't cleaned up
        if activity != nil {
            Task { await end() }
        }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName, startedAt: startedAt)
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // local-only updates; no push notifications needed
            )
        } catch {
            // Common failure modes: user denied permission, system at activity limit
            activity = nil
        }
    }

    /// Pushes a new ContentState to the running activity. Cheap to call — Apple
    /// rate-limits internally; the layout's `Text(timerInterval:)` views handle
    /// per-second tick updates without any push from us.
    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    /// Ends the active workout Live Activity immediately.
    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }

    /// Synchronous convenience for places that can't await.
    func endNow() {
        let current = activity
        activity = nil
        Task {
            await current?.end(nil, dismissalPolicy: .immediate)
        }
    }
}
