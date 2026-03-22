import Foundation
import Supabase

@Observable
final class DashboardViewModel {
    var recentSession: WorkoutSession?
    var weeklySetCount: Int = 0
    var totalSessionCount: Int = 0
    /// Which weekdays (0=Sun, 1=Mon, ..., 6=Sat) had a completed workout this week
    var weeklyTrainingDays: Set<Int> = []
    /// All dates (start of day) that had a completed workout
    var allTrainingDates: Set<Date> = []
    var isLoading = false
    var templateCount: Int = 0
    var templates: [Template] = []

    private let workoutService = WorkoutService()
    private let templateService = TemplateService()

    func loadDashboard() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            async let sessions = workoutService.fetchRecentSessions(userId: userId, limit: 1)
            async let setCount = workoutService.fetchWeeklySetCount(userId: userId)
            async let allSessions = workoutService.fetchAllSessions(userId: userId)
            async let templates = templateService.fetchTemplates(userId: userId)

            recentSession = try await sessions.first
            weeklySetCount = try await setCount
            let loadedSessions = try await allSessions
            totalSessionCount = loadedSessions.filter { $0.status == .completed }.count

            // Compute which days this week had workouts
            let calendar = Calendar.current
            let completedDates = loadedSessions
                .filter { $0.status == .completed }
                .compactMap(\.completedAt)

            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                weeklyTrainingDays = Set(
                    completedDates
                        .filter { weekInterval.contains($0) }
                        .map { calendar.component(.weekday, from: $0) - 1 } // 0=Sun..6=Sat
                )
            }

            // All training dates (day granularity) for calendar view
            allTrainingDates = Set(completedDates.map { calendar.startOfDay(for: $0) })

            let loadedTemplates = try await templates
            self.templates = loadedTemplates
            templateCount = loadedTemplates.count

            // Sync widget data
            WidgetService.syncFromDashboard(
                streak: 0,
                weeklySetCount: weeklySetCount,
                lastSession: recentSession?.completedAt
            )
        } catch {
            // Silently handle - dashboard is non-critical
        }
        isLoading = false
    }
}
