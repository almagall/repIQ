import Foundation
import Supabase

@Observable
final class DashboardViewModel {
    var recentSession: WorkoutSession?
    var weeklySetCount: Int = 0
    var isLoading = false
    var templateCount: Int = 0

    private let workoutService = WorkoutService()
    private let templateService = TemplateService()

    func loadDashboard() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            async let sessions = workoutService.fetchRecentSessions(userId: userId, limit: 1)
            async let setCount = workoutService.fetchWeeklySetCount(userId: userId)
            async let templates = templateService.fetchTemplates(userId: userId)

            recentSession = try await sessions.first
            weeklySetCount = try await setCount
            templateCount = try await templates.count
        } catch {
            // Silently handle - dashboard is non-critical
        }
        isLoading = false
    }
}
