import Foundation
import WidgetKit

/// Syncs workout data to shared UserDefaults for the home screen widget.
/// Requires App Group "group.com.repiq.shared" configured in both targets.
///
/// The widget runs in a separate process (the activity extension) and reads
/// these keys directly via `UserDefaults(suiteName:)`. Keep the keys in sync
/// with `repIQActivityBundle.swift` if you rename anything.
struct WidgetService {
    static let appGroupSuite = "group.com.repiq.shared"
    private static let defaults = UserDefaults(suiteName: appGroupSuite)

    /// Snapshot of the data the home screen widget renders. Pass `nil` for
    /// any field you don't have yet — the widget falls back gracefully.
    struct Snapshot {
        var weeklyWorkingSetCount: Int
        var lastWorkoutDate: Date?
        var lastPRSummary: String?

        static let empty = Snapshot(
            weeklyWorkingSetCount: 0,
            lastWorkoutDate: nil,
            lastPRSummary: nil
        )
    }

    /// Pushes a fresh snapshot to the App Group and asks WidgetKit to refresh.
    static func sync(_ snapshot: Snapshot) {
        defaults?.set(snapshot.weeklyWorkingSetCount, forKey: Keys.weeklyWorkingSetCount)
        defaults?.set(snapshot.lastWorkoutDate, forKey: Keys.lastWorkoutDate)
        defaults?.set(snapshot.lastPRSummary, forKey: Keys.lastPRSummary)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Targeted update for the field the workout completion path knows about
    /// without re-fetching the full dashboard snapshot. The rest of the
    /// snapshot fills in on the next dashboard load.
    static func updateAfterWorkoutCompletion(lastWorkoutDate: Date) {
        defaults?.set(lastWorkoutDate, forKey: Keys.lastWorkoutDate)
        WidgetCenter.shared.reloadAllTimelines()
    }

    enum Keys {
        static let weeklyWorkingSetCount = "widget_weeklyWorkingSetCount"
        static let lastWorkoutDate = "widget_lastWorkoutDate"
        static let lastPRSummary = "widget_lastPRSummary"
    }
}
