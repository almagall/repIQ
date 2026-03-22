import Foundation
import Supabase

@Observable
final class DashboardViewModel {
    var recentSession: WorkoutSession?
    var weeklySetCount: Int = 0
    var totalSessionCount: Int = 0
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
            let loadedTemplates = try await templates
            self.templates = loadedTemplates
            templateCount = loadedTemplates.count

            // Sync widget data
            WidgetService.syncFromDashboard(
                streak: 0, // Streak is loaded by analytics; will be updated next refresh
                weeklySetCount: weeklySetCount,
                lastSession: recentSession?.completedAt
            )
        } catch {
            // Silently handle - dashboard is non-critical
        }
        isLoading = false
    }
}
