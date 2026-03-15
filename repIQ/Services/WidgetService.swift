import Foundation
import WidgetKit

/// Syncs workout data to shared UserDefaults for the home screen widget.
/// Requires App Group "group.com.repiq.shared" configured in both targets.
struct WidgetService {
    private static let defaults = UserDefaults(suiteName: "group.com.repiq.shared")

    /// Call after workout completion or on app launch to sync widget data.
    static func syncWidgetData(
        currentStreak: Int,
        weeklySessionCount: Int,
        lastWorkoutDate: Date?,
        nextWorkoutName: String?
    ) {
        defaults?.set(currentStreak, forKey: "widget_currentStreak")
        defaults?.set(weeklySessionCount, forKey: "widget_weeklySessionCount")
        defaults?.set(lastWorkoutDate, forKey: "widget_lastWorkoutDate")
        defaults?.set(nextWorkoutName, forKey: "widget_nextWorkoutName")

        // Tell WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Convenience to sync from analytics data.
    static func syncFromDashboard(streak: Int, weeklySetCount: Int, lastSession: Date?) {
        syncWidgetData(
            currentStreak: streak,
            weeklySessionCount: weeklySetCount,
            lastWorkoutDate: lastSession,
            nextWorkoutName: nil
        )
    }
}
