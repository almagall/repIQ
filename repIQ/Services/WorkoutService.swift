import Foundation
import Supabase

struct WorkoutService: Sendable {

    // MARK: - Session Queries

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

    /// Fetches all completed workout sessions for the user, ordered by completion date.
    func fetchAllSessions(userId: UUID) async throws -> [WorkoutSession] {
        try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches a single session with all its sets for the detail view.
    func fetchSessionDetail(sessionId: UUID) async throws -> (session: WorkoutSession, sets: [WorkoutSet]) {
        let session: WorkoutSession = try await supabase.from("workout_sessions")
            .select()
            .eq("id", value: sessionId.uuidString)
            .single()
            .execute()
            .value

        let sets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select()
            .eq("session_id", value: sessionId.uuidString)
            .order("set_number")
            .execute()
            .value

        return (session: session, sets: sets)
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

    /// Batch fetch previous sets for multiple exercises (avoids N+1 queries).
    /// Returns a dictionary keyed by exerciseId with arrays of sets from the most recent completed session.
    func fetchPreviousSetsForExercises(
        exerciseIds: [UUID],
        userId: UUID
    ) async throws -> [UUID: [WorkoutSet]] {
        // Get the most recent completed session
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let lastSession = sessions.first else { return [:] }

        // Fetch all sets from that session for the given exercise IDs
        let allSets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select()
            .eq("session_id", value: lastSession.id.uuidString)
            .in("exercise_id", values: exerciseIds.map(\.uuidString))
            .order("set_number")
            .execute()
            .value

        // Group by exerciseId
        var result: [UUID: [WorkoutSet]] = [:]
        for set in allSets {
            result[set.exerciseId, default: []].append(set)
        }
        return result
    }

    // MARK: - Session CRUD

    /// Creates a new in-progress workout session.
    /// - Parameter startDate: The date to record for this workout. Defaults to now.
    func createSession(
        userId: UUID,
        templateId: UUID?,
        workoutDayId: UUID?,
        startDate: Date = Date()
    ) async throws -> WorkoutSession {
        struct CreateSession: Encodable {
            let id: UUID
            let user_id: String
            let template_id: String?
            let workout_day_id: String?
            let status: String
            let started_at: String
        }

        let sessionId = UUID()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = CreateSession(
            id: sessionId,
            user_id: userId.uuidString,
            template_id: templateId?.uuidString,
            workout_day_id: workoutDayId?.uuidString,
            status: "in_progress",
            started_at: formatter.string(from: startDate)
        )

        let session: WorkoutSession = try await supabase.from("workout_sessions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return session
    }

    /// Updates session status to completed with timestamps.
    func completeSession(
        sessionId: UUID,
        durationSeconds: Int,
        notes: String? = nil
    ) async throws {
        struct UpdateSession: Encodable {
            let status: String
            let completed_at: String
            let duration_seconds: Int
            let notes: String?
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = UpdateSession(
            status: "completed",
            completed_at: formatter.string(from: Date()),
            duration_seconds: durationSeconds,
            notes: notes
        )

        try await supabase.from("workout_sessions")
            .update(payload)
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    /// Updates session status to abandoned.
    func abandonSession(sessionId: UUID) async throws {
        try await supabase.from("workout_sessions")
            .update(["status": "abandoned"])
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    // MARK: - Set CRUD

    /// Inserts a completed set. Returns the created WorkoutSet with server ID.
    func saveSet(
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        setType: SetType,
        weight: Double,
        reps: Int,
        rpe: Double?,
        isPR: Bool = false
    ) async throws -> WorkoutSet {
        struct CreateSet: Encodable {
            let id: UUID
            let session_id: String
            let exercise_id: String
            let set_number: Int
            let set_type: String
            let weight: Double
            let reps: Int
            let rpe: Double?
            let is_pr: Bool
            let completed_at: String
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = CreateSet(
            id: UUID(),
            session_id: sessionId.uuidString,
            exercise_id: exerciseId.uuidString,
            set_number: setNumber,
            set_type: setType.rawValue,
            weight: weight,
            reps: reps,
            rpe: rpe,
            is_pr: isPR,
            completed_at: formatter.string(from: Date())
        )

        let workoutSet: WorkoutSet = try await supabase.from("workout_sets")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return workoutSet
    }

    /// Updates an existing set's weight, reps, and RPE.
    func updateSet(id: UUID, weight: Double, reps: Int, rpe: Double?) async throws {
        struct UpdatePayload: Encodable {
            let weight: Double
            let reps: Int
            let rpe: Double?
        }

        try await supabase.from("workout_sets")
            .update(UpdatePayload(weight: weight, reps: reps, rpe: rpe))
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Updates the completed_at date of a session.
    func updateSessionDate(sessionId: UUID, completedAt: Date) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try await supabase.from("workout_sessions")
            .update(["completed_at": formatter.string(from: completedAt)])
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    /// Deletes a set by ID.
    func deleteSet(id: UUID) async throws {
        try await supabase.from("workout_sets")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Name Lookups

    /// Batch-fetch template names by ID.
    func fetchTemplateNames(ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }

        struct NameRow: Decodable { let id: UUID; let name: String }

        let rows: [NameRow] = try await supabase.from("templates")
            .select("id, name")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
    }

    /// Batch-fetch workout day names by ID.
    func fetchWorkoutDayNames(ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }

        struct NameRow: Decodable { let id: UUID; let name: String }

        let rows: [NameRow] = try await supabase.from("workout_days")
            .select("id, name")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
    }
}
