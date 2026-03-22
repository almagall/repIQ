import Foundation
import Supabase

struct GoalService: Sendable {

    func fetchGoals(userId: UUID) async throws -> [Goal] {
        try await supabase.from("goals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchActiveGoals(userId: UUID) async throws -> [Goal] {
        try await supabase.from("goals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createGoal(
        userId: UUID,
        goalType: GoalType,
        exerciseId: UUID?,
        exerciseName: String?,
        targetValue: Double,
        startingValue: Double,
        isEstimated1RM: Bool,
        unit: String,
        targetDate: Date?
    ) async throws -> Goal {
        struct CreatePayload: Encodable {
            let user_id: String
            let goal_type: String
            let exercise_id: String?
            let exercise_name: String?
            let target_value: Double
            let current_value: Double
            let starting_value: Double
            let is_estimated_1rm: Bool
            let unit: String
            let target_date: String?
            let status: String
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return try await supabase.from("goals")
            .insert(CreatePayload(
                user_id: userId.uuidString,
                goal_type: goalType.rawValue,
                exercise_id: exerciseId?.uuidString,
                exercise_name: exerciseName,
                target_value: targetValue,
                current_value: startingValue,
                starting_value: startingValue,
                is_estimated_1rm: isEstimated1RM,
                unit: unit,
                target_date: targetDate.map { formatter.string(from: $0) },
                status: "active"
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func updateGoalProgress(goalId: UUID, currentValue: Double) async throws {
        try await supabase.from("goals")
            .update(["current_value": "\(currentValue)"])
            .eq("id", value: goalId.uuidString)
            .execute()
    }

    func completeGoal(goalId: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try await supabase.from("goals")
            .update([
                "status": "completed",
                "completed_at": formatter.string(from: Date())
            ])
            .eq("id", value: goalId.uuidString)
            .execute()
    }

    func abandonGoal(goalId: UUID) async throws {
        try await supabase.from("goals")
            .update(["status": "abandoned"])
            .eq("id", value: goalId.uuidString)
            .execute()
    }

    func deleteGoal(goalId: UUID) async throws {
        try await supabase.from("goals")
            .delete()
            .eq("id", value: goalId.uuidString)
            .execute()
    }

    /// Fetches the current best weight or e1RM for an exercise to use as starting value.
    func fetchCurrentBest(userId: UUID, exerciseId: UUID, isEstimated1RM: Bool) async throws -> Double {
        let sets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select("*, workout_sessions!inner(*)")
            .eq("workout_sessions.user_id", value: userId.uuidString)
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("workout_sessions.status", value: "completed")
            .execute()
            .value

        if isEstimated1RM {
            return sets.map(\.estimated1RM).max() ?? 0
        } else {
            return sets.map(\.weight).max() ?? 0
        }
    }

    /// Syncs goal progress based on actual training data.
    func syncGoalProgress(goal: Goal, userId: UUID) async throws -> Double {
        switch goal.goalType {
        case .weight:
            guard let exerciseId = goal.exerciseId else { return goal.currentValue }

            if goal.isEstimated1RM {
                // Find max estimated 1RM for this exercise
                let sets: [WorkoutSet] = try await supabase.from("workout_sets")
                    .select("*, workout_sessions!inner(*)")
                    .eq("workout_sessions.user_id", value: userId.uuidString)
                    .eq("exercise_id", value: exerciseId.uuidString)
                    .eq("workout_sessions.status", value: "completed")
                    .execute()
                    .value
                return sets.map(\.estimated1RM).max() ?? 0
            } else {
                // Find the max weight lifted for this exercise
                let sets: [WorkoutSet] = try await supabase.from("workout_sets")
                    .select("*, workout_sessions!inner(*)")
                    .eq("workout_sessions.user_id", value: userId.uuidString)
                    .eq("exercise_id", value: exerciseId.uuidString)
                    .eq("workout_sessions.status", value: "completed")
                    .order("weight", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                return sets.first?.weight ?? 0
            }

        case .reps:
            guard let exerciseId = goal.exerciseId else { return goal.currentValue }
            let sets: [WorkoutSet] = try await supabase.from("workout_sets")
                .select("*, workout_sessions!inner(*)")
                .eq("workout_sessions.user_id", value: userId.uuidString)
                .eq("exercise_id", value: exerciseId.uuidString)
                .eq("workout_sessions.status", value: "completed")
                .order("reps", ascending: false)
                .limit(1)
                .execute()
                .value
            return Double(sets.first?.reps ?? 0)

        case .consistency:
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "completed")
                .gte("completed_at", value: formatter.string(from: weekStart))
                .execute()
                .value
            return Double(sessions.count)

        case .volume, .bodyweight:
            return goal.currentValue
        }
    }
}
