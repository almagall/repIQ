import Foundation
import Supabase

struct WorkoutService: Sendable {

    // MARK: - Sessions

    func fetchRecentSessions(userId: UUID, limit: Int = 5) async throws -> [WorkoutSession] {
        try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchWeeklySetCount(userId: UUID) async throws -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let formatter = ISO8601DateFormatter()

        let sets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select("*, workout_sessions!inner(user_id)")
            .eq("workout_sessions.user_id", value: userId.uuidString)
            .gte("completed_at", value: formatter.string(from: startOfWeek))
            .eq("set_type", value: "working")
            .execute()
            .value

        return sets.count
    }

    // MARK: - Previous Session Data

    func fetchPreviousSetsForExercise(exerciseId: UUID, userId: UUID, limit: Int = 3) async throws -> [[WorkoutSet]] {
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        var result: [[WorkoutSet]] = []
        for session in sessions {
            let sets: [WorkoutSet] = try await supabase.from("workout_sets")
                .select()
                .eq("session_id", value: session.id.uuidString)
                .eq("exercise_id", value: exerciseId.uuidString)
                .eq("set_type", value: "working")
                .order("set_number")
                .execute()
                .value
            if !sets.isEmpty {
                result.append(sets)
            }
        }
        return result
    }
}
