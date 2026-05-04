import Foundation
import Supabase

/// Generates weekly digests and monthly wrapped reports.
struct DigestService: Sendable {

    // MARK: - Weekly Digest

    /// Generates a weekly digest summarizing friend circle activity.
    func generateWeeklyDigest(userId: UUID, friendIds: [UUID]) async throws -> WeeklyDigest {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekStartStr = ISO8601DateFormatter().string(from: weekStart)

        // Check if digest already exists for this week
        let existing: [WeeklyDigest] = try await supabase.from("weekly_digests")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("week_start", value: formatDate(weekStart))
            .limit(1)
            .execute()
            .value

        if let digest = existing.first { return digest }

        // Gather data for the digest
        guard !friendIds.isEmpty else {
            return try await createDigest(
                userId: userId, weekStart: weekStart,
                friendsTrained: 0, totalPRs: 0, totalWorkouts: 0,
                topPerformerId: nil, topPerformerWorkouts: 0,
                highlights: [], leagueChanges: []
            )
        }

        // Friend workout counts this week
        struct SessionRow: Decodable { let user_id: UUID }
        let sessions: [SessionRow] = try await supabase.from("workout_sessions")
            .select("user_id")
            .in("user_id", values: friendIds.map(\.uuidString))
            .eq("status", value: "completed")
            .gte("completed_at", value: weekStartStr)
            .execute()
            .value

        var friendWorkoutCounts: [UUID: Int] = [:]
        for s in sessions { friendWorkoutCounts[s.user_id, default: 0] += 1 }
        let friendsTrained = friendWorkoutCounts.count
        let totalWorkouts = sessions.count

        // Top performer
        let topPerformer = friendWorkoutCounts.max(by: { $0.value < $1.value })

        // Friend PR count this week
        struct PRRow: Decodable { let id: UUID }
        let prs: [PRRow] = try await supabase.from("personal_records")
            .select("id")
            .in("user_id", values: friendIds.map(\.uuidString))
            .gte("achieved_at", value: weekStartStr)
            .execute()
            .value

        // Build highlights
        var highlights: [DigestHighlight] = []
        if prs.count > 0 {
            highlights.append(DigestHighlight(
                type: "prs", message: "\(prs.count) PR\(prs.count == 1 ? " was" : "s were") hit this week",
                userId: nil, username: nil
            ))
        }

        return try await createDigest(
            userId: userId, weekStart: weekStart,
            friendsTrained: friendsTrained, totalPRs: prs.count,
            totalWorkouts: totalWorkouts,
            topPerformerId: topPerformer?.key,
            topPerformerWorkouts: topPerformer?.value ?? 0,
            highlights: highlights, leagueChanges: []
        )
    }

    /// Fetches recent digests for the user.
    func fetchDigests(userId: UUID, limit: Int = 10) async throws -> [WeeklyDigest] {
        try await supabase.from("weekly_digests")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("week_start", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Marks a digest as read.
    func markRead(digestId: UUID) async throws {
        struct Payload: Encodable { let is_read: Bool }
        try await supabase.from("weekly_digests")
            .update(Payload(is_read: true))
            .eq("id", value: digestId.uuidString)
            .execute()
    }

    /// Fetches the unread digest count.
    func unreadCount(userId: UUID) async throws -> Int {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await supabase.from("weekly_digests")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value
        return rows.count
    }

    // MARK: - Monthly Wrapped

    /// Generates a Spotify-style monthly training report card for the *prior*
    /// calendar month. Idempotent via the unique (user_id, month_start)
    /// constraint — calling this multiple times returns the existing row.
    func generateMonthlyWrapped(userId: UUID) async throws -> MonthlyWrapped {
        let calendar = Calendar.current
        let now = Date()
        // Prior month boundaries: monthStart = 1st of last month, monthEnd = 1st of current month.
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -1, to: now)!))!
        let monthEnd = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        if let existing = try await fetchExistingWrapped(userId: userId, monthStart: monthStart) {
            return existing
        }

        let monthStartStr = ISO8601DateFormatter().string(from: monthStart)
        let monthEndStr = ISO8601DateFormatter().string(from: monthEnd)

        // 1) Sessions for the month.
        struct SessionRow: Decodable {
            let id: UUID
            let duration_seconds: Int?
            let completed_at: String?
        }
        let sessions: [SessionRow] = try await supabase.from("workout_sessions")
            .select("id, duration_seconds, completed_at")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: monthStartStr)
            .lt("completed_at", value: monthEndStr)
            .execute()
            .value

        // 2) Sets — for volume, set count, top exercise, and per-session unique-exercise stats.
        struct SetRow: Decodable {
            let session_id: UUID
            let exercise_id: UUID
            let weight: Double
            let reps: Int
            let set_type: String?
        }
        let sessionIds = sessions.map(\.id)
        var totalVolume: Double = 0
        var totalSets = 0
        var exerciseVolumes: [UUID: Double] = [:]
        var workingSetsByExercise: [UUID: Int] = [:]
        var exercisesPerSession: [UUID: Set<UUID>] = [:]

        if !sessionIds.isEmpty {
            let sets: [SetRow] = try await supabase.from("workout_sets")
                .select("session_id, exercise_id, weight, reps, set_type")
                .in("session_id", values: sessionIds.map(\.uuidString))
                .execute()
                .value

            for s in sets {
                let isWorking = (s.set_type ?? "working") == "working"
                let vol = s.weight * Double(s.reps)
                totalVolume += vol
                exerciseVolumes[s.exercise_id, default: 0] += vol
                exercisesPerSession[s.session_id, default: []].insert(s.exercise_id)
                if isWorking {
                    totalSets += 1
                    workingSetsByExercise[s.exercise_id, default: 0] += 1
                }
            }
        }

        // 3) Resolve exercise names + muscle groups in one batch.
        let allExerciseIds = Array(Set(exerciseVolumes.keys))
        struct ExerciseRow: Decodable {
            let id: UUID
            let name: String
            let muscle_group: String
        }
        var exerciseLookup: [UUID: ExerciseRow] = [:]
        if !allExerciseIds.isEmpty {
            let rows: [ExerciseRow] = try await supabase.from("exercises")
                .select("id, name, muscle_group")
                .in("id", values: allExerciseIds.map(\.uuidString))
                .execute()
                .value
            for row in rows { exerciseLookup[row.id] = row }
        }

        // 4) Top exercise by total volume.
        let topExerciseId = exerciseVolumes.max(by: { $0.value < $1.value })?.key
        let topExerciseName = topExerciseId.flatMap { exerciseLookup[$0]?.name }
        let topExerciseVolume = topExerciseId.flatMap { exerciseVolumes[$0] }

        // 5) Most consistent muscle = the muscle group that absorbed the most working sets.
        var workingSetsByMuscle: [String: Int] = [:]
        for (exerciseId, count) in workingSetsByExercise {
            guard let muscle = exerciseLookup[exerciseId]?.muscle_group else { continue }
            workingSetsByMuscle[muscle, default: 0] += count
        }
        let mostConsistentMuscle = workingSetsByMuscle.max(by: { $0.value < $1.value })?.key

        // 6) PRs this month — proper join, not the broken exercise_name column.
        struct PRJoinRow: Decodable {
            struct ExName: Decodable { let name: String }
            let value: Double
            let record_type: String
            let reps_at_weight: Int?
            let exercises: ExName?
        }
        let prs: [PRJoinRow] = try await supabase.from("personal_records")
            .select("value, record_type, reps_at_weight, exercises(name)")
            .eq("user_id", value: userId.uuidString)
            .gte("achieved_at", value: monthStartStr)
            .lt("achieved_at", value: monthEndStr)
            .execute()
            .value

        let weightPRs = prs.filter { $0.record_type == "weight" || $0.record_type == "estimated_1rm" }
        let biggestPR = weightPRs.max(by: { $0.value < $1.value })

        // 7) Average session duration.
        let durations = sessions.compactMap(\.duration_seconds)
        let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / durations.count

        // 8) Favorite day of week.
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let isoFormatter = ISO8601DateFormatter()
        var dayCounts: [String: Int] = [:]
        var sessionDates: [Date] = []
        for s in sessions {
            guard let dateStr = s.completed_at, let date = isoFormatter.date(from: dateStr) else { continue }
            sessionDates.append(date)
            let dayName = dayFormatter.string(from: date)
            dayCounts[dayName, default: 0] += 1
        }
        let favoriteDay = dayCounts.max(by: { $0.value < $1.value })?.key

        // 9) Real longest streak from session dates (consecutive distinct days).
        let longestStreak = longestConsecutiveDayStreak(in: sessionDates, calendar: calendar)

        // 10) Archetype reveal.
        let avgUniqueExercises = sessions.isEmpty ? 0 :
            Double(exercisesPerSession.values.map(\.count).reduce(0, +)) / Double(sessions.count)
        let archetype = WrappedArchetype.classify(.init(
            totalSessions: sessions.count,
            totalPRs: prs.count,
            totalVolume: totalVolume,
            longestStreak: longestStreak,
            avgUniqueExercisesPerSession: avgUniqueExercises
        ))

        struct InsertPayload: Encodable {
            let user_id: String
            let month_start: String
            let total_sessions: Int
            let total_volume: Double
            let total_sets: Int
            let total_prs: Int
            let top_exercise_name: String?
            let top_exercise_volume: Double?
            let most_consistent_muscle: String?
            let biggest_pr_exercise: String?
            let biggest_pr_value: Double?
            let biggest_pr_type: String?
            let avg_session_duration: Int?
            let longest_streak: Int
            let favorite_day: String?
            let archetype: String
        }

        let result: MonthlyWrapped = try await supabase.from("monthly_wrapped")
            .insert(InsertPayload(
                user_id: userId.uuidString,
                month_start: formatDate(monthStart),
                total_sessions: sessions.count,
                total_volume: totalVolume,
                total_sets: totalSets,
                total_prs: prs.count,
                top_exercise_name: topExerciseName,
                top_exercise_volume: topExerciseVolume,
                most_consistent_muscle: mostConsistentMuscle,
                biggest_pr_exercise: biggestPR?.exercises?.name,
                biggest_pr_value: biggestPR?.value,
                biggest_pr_type: biggestPR?.record_type,
                avg_session_duration: avgDuration,
                longest_streak: longestStreak,
                favorite_day: favoriteDay,
                archetype: archetype.rawValue
            ))
            .select()
            .single()
            .execute()
            .value

        return result
    }

    /// Marks a wrapped as viewed so the dashboard banner + Progress-tab dot
    /// badge can clear. Safe to call repeatedly — idempotent on the server.
    func markWrappedViewed(wrappedId: UUID) async throws {
        struct Payload: Encodable { let viewed_at: String }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try await supabase.from("monthly_wrapped")
            .update(Payload(viewed_at: formatter.string(from: Date())))
            .eq("id", value: wrappedId.uuidString)
            .execute()
    }

    /// Returns the prior-month wrapped row if it already exists (without
    /// generating one). Used by the dashboard banner to know whether to show
    /// the "Your X Wrapped is ready" CTA.
    func fetchPriorMonthWrapped(userId: UUID) async throws -> MonthlyWrapped? {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -1, to: now)!))!
        return try await fetchExistingWrapped(userId: userId, monthStart: monthStart)
    }

    private func fetchExistingWrapped(userId: UUID, monthStart: Date) async throws -> MonthlyWrapped? {
        let existing: [MonthlyWrapped] = try await supabase.from("monthly_wrapped")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("month_start", value: formatDate(monthStart))
            .limit(1)
            .execute()
            .value
        return existing.first
    }

    /// Fetches past wrapped reports.
    func fetchWrappedHistory(userId: UUID, limit: Int = 12) async throws -> [MonthlyWrapped] {
        try await supabase.from("monthly_wrapped")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("month_start", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Private Helpers

    private func createDigest(
        userId: UUID, weekStart: Date,
        friendsTrained: Int, totalPRs: Int, totalWorkouts: Int,
        topPerformerId: UUID?, topPerformerWorkouts: Int,
        highlights: [DigestHighlight], leagueChanges: [LeagueChange]
    ) async throws -> WeeklyDigest {
        struct InsertPayload: Encodable {
            let user_id: String
            let week_start: String
            let friends_trained: Int
            let total_prs: Int
            let total_workouts: Int
            let top_performer_id: String?
            let top_performer_workouts: Int
            let highlights: [DigestHighlight]?
            let league_changes: [LeagueChange]?
        }

        return try await supabase.from("weekly_digests")
            .insert(InsertPayload(
                user_id: userId.uuidString,
                week_start: formatDate(weekStart),
                friends_trained: friendsTrained,
                total_prs: totalPRs,
                total_workouts: totalWorkouts,
                top_performer_id: topPerformerId?.uuidString,
                top_performer_workouts: topPerformerWorkouts,
                highlights: highlights.isEmpty ? nil : highlights,
                league_changes: leagueChanges.isEmpty ? nil : leagueChanges
            ))
            .select()
            .single()
            .execute()
            .value
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Longest run of consecutive distinct calendar days that contained at
    /// least one session. Two sessions on the same day count as one day.
    /// Returns 0 if there are no sessions.
    private func longestConsecutiveDayStreak(in dates: [Date], calendar: Calendar) -> Int {
        guard !dates.isEmpty else { return 0 }
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            let prev = days[i - 1]
            let next = days[i]
            if let stepped = calendar.date(byAdding: .day, value: 1, to: prev), stepped == next {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
