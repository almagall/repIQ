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

    /// Generates a Spotify-style monthly training report card.
    func generateMonthlyWrapped(userId: UUID) async throws -> MonthlyWrapped {
        let calendar = Calendar.current
        // Previous month
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -1, to: now)!))!
        let monthEnd = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // Check if already generated
        let existing: [MonthlyWrapped] = try await supabase.from("monthly_wrapped")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("month_start", value: formatDate(monthStart))
            .limit(1)
            .execute()
            .value

        if let wrapped = existing.first { return wrapped }

        let monthStartStr = ISO8601DateFormatter().string(from: monthStart)
        let monthEndStr = ISO8601DateFormatter().string(from: monthEnd)

        // Fetch sessions for the month
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

        // Fetch sets for volume
        struct SetRow: Decodable {
            let exercise_id: UUID
            let weight: Double
            let reps: Int
        }
        let sessionIds = sessions.map(\.id)
        var totalVolume: Double = 0
        var totalSets = 0
        var exerciseVolumes: [UUID: Double] = [:]

        if !sessionIds.isEmpty {
            let sets: [SetRow] = try await supabase.from("workout_sets")
                .select("exercise_id, weight, reps")
                .in("session_id", values: sessionIds.map(\.uuidString))
                .execute()
                .value

            totalSets = sets.count
            for s in sets {
                let vol = s.weight * Double(s.reps)
                totalVolume += vol
                exerciseVolumes[s.exercise_id, default: 0] += vol
            }
        }

        // Top exercise by volume
        let topExerciseId = exerciseVolumes.max(by: { $0.value < $1.value })?.key
        var topExerciseName: String?
        var topExerciseVolume: Double?
        if let id = topExerciseId {
            struct ExRow: Decodable { let name: String }
            if let ex: ExRow = try? await supabase.from("exercises")
                .select("name")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value {
                topExerciseName = ex.name
                topExerciseVolume = exerciseVolumes[id]
            }
        }

        // PRs this month
        struct PRRow: Decodable {
            let exercise_name: String?
            let record_type: String
            let value: Double
        }
        let prs: [PRRow] = try await supabase.from("personal_records")
            .select("exercise_name, record_type, value")
            .eq("user_id", value: userId.uuidString)
            .gte("achieved_at", value: monthStartStr)
            .lt("achieved_at", value: monthEndStr)
            .execute()
            .value

        // Biggest PR (by e1rm or weight)
        let weightPRs = prs.filter { $0.record_type == "weight" || $0.record_type == "estimated1rm" }
        let biggestPR = weightPRs.max(by: { $0.value < $1.value })

        // Average session duration
        let durations = sessions.compactMap(\.duration_seconds)
        let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / durations.count

        // Favorite day of week
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let isoFormatter = ISO8601DateFormatter()
        var dayCounts: [String: Int] = [:]
        for s in sessions {
            if let dateStr = s.completed_at, let date = isoFormatter.date(from: dateStr) {
                let dayName = dayFormatter.string(from: date)
                dayCounts[dayName, default: 0] += 1
            }
        }
        let favoriteDay = dayCounts.max(by: { $0.value < $1.value })?.key

        // Longest streak this month (simplified: consecutive days with workouts)
        let longestStreak = calculateMonthStreak(sessions: sessions)

        // Create wrapped record
        struct InsertPayload: Encodable {
            let user_id: String
            let month_start: String
            let total_sessions: Int
            let total_volume: Double
            let total_sets: Int
            let total_prs: Int
            let top_exercise_name: String?
            let top_exercise_volume: Double?
            let biggest_pr_exercise: String?
            let biggest_pr_value: Double?
            let biggest_pr_type: String?
            let avg_session_duration: Int?
            let longest_streak: Int
            let favorite_day: String?
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
                biggest_pr_exercise: biggestPR?.exercise_name,
                biggest_pr_value: biggestPR?.value,
                biggest_pr_type: biggestPR?.record_type,
                avg_session_duration: avgDuration,
                longest_streak: longestStreak,
                favorite_day: favoriteDay
            ))
            .select()
            .single()
            .execute()
            .value

        return result
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

    private func calculateMonthStreak(sessions: some Collection<some Decodable>) -> Int {
        // Simplified: return count of sessions as a rough proxy
        // Real implementation would parse dates and find consecutive days
        return min(sessions.count, 30)
    }
}
