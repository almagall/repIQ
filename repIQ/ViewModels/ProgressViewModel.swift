import Foundation
import Supabase

@Observable
final class ProgressViewModel {
    var sessions: [WorkoutSession] = []
    var isLoading = false

    // Detail view state
    var sessionDetail: SessionWithSets?
    var isLoadingDetail = false

    private let workoutService = WorkoutService()
    private let exerciseService = ExerciseLibraryService()

    // MARK: - Computed Stats

    var weeklySessionCount: Int {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessions.filter { ($0.completedAt ?? $0.startedAt) >= startOfWeek }.count
    }

    var monthlySessionCount: Int {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start else { return 0 }
        return sessions.filter { ($0.completedAt ?? $0.startedAt) >= startOfMonth }.count
    }

    var totalSessionCount: Int {
        sessions.count
    }

    // MARK: - Loading

    func loadHistory() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            sessions = try await workoutService.fetchAllSessions(userId: userId)
        } catch {
            // Silently handle - non-critical
        }
        isLoading = false
    }

    func loadSessionDetail(sessionId: UUID) async {
        isLoadingDetail = true
        do {
            let detail = try await workoutService.fetchSessionDetail(sessionId: sessionId)

            // Resolve exercise names
            let exerciseIds = Array(Set(detail.sets.map(\.exerciseId)))
            let names = try await exerciseService.fetchExercisesByIds(exerciseIds)

            sessionDetail = SessionWithSets(
                session: detail.session,
                sets: detail.sets,
                exerciseNames: names
            )
        } catch {
            // Silently handle
        }
        isLoadingDetail = false
    }
}
