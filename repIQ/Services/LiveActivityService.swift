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

    /// Begins a new Live Activity for the workout.
    ///
    /// **Orphan cleanup:** iOS keeps a Live Activity visible after the app
    /// process terminates, but our in-memory `activity` reference doesn't
    /// survive that — so on next launch we don't know about prior activities
    /// and `Activity.request(...)` would create a second one stacked on top
    /// of the orphan, producing visually corrupted/overlapping renders. To
    /// avoid that, we always enumerate `Activity<...>.activities` and end
    /// every existing one before requesting the new activity.
    ///
    /// Async because `end(_:dismissalPolicy:)` is async and we need to wait
    /// for the cleanup to complete before requesting the new activity.
    func start(workoutName: String, startedAt: Date, initialState: WorkoutActivityAttributes.ContentState) async {
        guard isAvailable else { return }

        // Defensive cleanup: end every existing activity (our own + orphans
        // from prior app sessions) before creating a new one. Without this,
        // a force-quit-then-relaunch would stack a second activity on top
        // of the orphan and iOS would render them combined / corrupted.
        for existing in Activity<WorkoutActivityAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil

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

    /// Ends every running Live Activity of this type. Called at app launch
    /// so orphans from prior sessions are cleaned up immediately, before
    /// the user even starts a new workout.
    func cleanupOrphans() async {
        for orphan in Activity<WorkoutActivityAttributes>.activities {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
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
