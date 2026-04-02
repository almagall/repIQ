import Foundation
import Supabase

// MARK: - Helper Structs for Progress Queries

nonisolated private struct ProgressCountRow: Decodable, Sendable { let count: Int }
nonisolated private struct ProgressProfileRow: Decodable, Sendable { let current_streak: Int; let longest_streak: Int }
nonisolated private struct ProgressVolumeRow: Decodable, Sendable { let total_volume: Double }
nonisolated private struct ProgressExerciseRow: Decodable, Sendable { let exercise_id: UUID }
nonisolated private struct ProgressMuscleRow: Decodable, Sendable { let muscle_group: String }

/// Manages IQ points, streaks, leagues, and badges.
/// No gems, no streak freezes — all rewards are earned through actual training.
struct GamificationService: Sendable {

    // MARK: - IQ Points

    /// Awards IQ points for a training action.
    func awardPoints(userId: UUID, points: Int, reason: IQPointReason, referenceId: UUID? = nil) async throws {
        struct CreatePayload: Encodable {
            let user_id: String
            let points: Int
            let reason: String
            let reference_id: String?
        }

        try await supabase.from("iq_points_ledger")
            .insert(CreatePayload(
                user_id: userId.uuidString,
                points: points,
                reason: reason.rawValue,
                reference_id: referenceId?.uuidString
            ))
            .execute()

        // Update total_iq on profile
        let profile = try await fetchIQTotal(userId: userId)
        let newTotal = profile + points
        try await supabase.from("profiles")
            .update(["total_iq": newTotal])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Fetches the user's total IQ points.
    private func fetchIQTotal(userId: UUID) async throws -> Int {
        struct IQRow: Decodable { let total_iq: Int }
        let row: IQRow = try await supabase.from("profiles")
            .select("total_iq")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return row.total_iq
    }

    /// Fetches weekly IQ points for a user (for league ranking).
    func fetchWeeklyIQ(userId: UUID) async throws -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let formatter = ISO8601DateFormatter()

        let entries: [IQPointEntry] = try await supabase.from("iq_points_ledger")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("created_at", value: formatter.string(from: startOfWeek))
            .execute()
            .value

        return entries.reduce(0) { $0 + $1.points }
    }

    /// Fetches IQ point history for the user.
    func fetchPointHistory(userId: UUID, limit: Int = 50) async throws -> [IQPointEntry] {
        try await supabase.from("iq_points_ledger")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Workout Completion Rewards

    /// Awards all IQ points for a completed workout.
    /// Call this from `completeWorkout()` to award points based on actual training.
    ///
    /// Points breakdown (earned through training only, no shortcuts):
    /// - +1 per completed working set
    /// - +3 per target hit
    /// - +10 for completing the full session
    /// - +25 per new PR
    /// - +15 streak bonus (if maintaining a streak)
    func awardWorkoutRewards(
        userId: UUID,
        sessionId: UUID,
        completedSets: Int,
        targetsHit: Int,
        newPRCount: Int,
        currentStreak: Int
    ) async throws -> Int {
        var totalPoints = 0

        // Set completion points
        if completedSets > 0 {
            let setPoints = completedSets * IQPointReason.setCompleted.pointValue
            try await awardPoints(userId: userId, points: setPoints, reason: .setCompleted, referenceId: sessionId)
            totalPoints += setPoints
        }

        // Target hit points
        if targetsHit > 0 {
            let targetPoints = targetsHit * IQPointReason.targetHit.pointValue
            try await awardPoints(userId: userId, points: targetPoints, reason: .targetHit, referenceId: sessionId)
            totalPoints += targetPoints
        }

        // Session completion
        let sessionPoints = IQPointReason.sessionCompleted.pointValue
        try await awardPoints(userId: userId, points: sessionPoints, reason: .sessionCompleted, referenceId: sessionId)
        totalPoints += sessionPoints

        // PR points
        if newPRCount > 0 {
            let prPoints = newPRCount * IQPointReason.prAchieved.pointValue
            try await awardPoints(userId: userId, points: prPoints, reason: .prAchieved, referenceId: sessionId)
            totalPoints += prPoints
        }

        // Streak bonus (3+ day streak)
        if currentStreak >= 3 {
            let streakPoints = IQPointReason.streakBonus.pointValue
            try await awardPoints(userId: userId, points: streakPoints, reason: .streakBonus, referenceId: sessionId)
            totalPoints += streakPoints
        }

        return totalPoints
    }

    // MARK: - Streaks

    /// Updates the user's training streak. Call after every workout completion.
    /// Streaks break if you don't train — no freezes, no shortcuts.
    func updateStreak(userId: UUID) async throws -> (currentStreak: Int, longestStreak: Int) {
        struct StreakRow: Decodable {
            let current_streak: Int
            let longest_streak: Int
            let last_workout_date: String?
        }

        let row: StreakRow = try await supabase.from("profiles")
            .select("current_streak, longest_streak, last_workout_date")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var newStreak = row.current_streak
        var newLongest = row.longest_streak

        if let lastDateStr = row.last_workout_date,
           let lastDate = dateFormatter.date(from: lastDateStr) {
            let lastWorkoutDay = Calendar.current.startOfDay(for: lastDate)
            let daysSince = Calendar.current.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

            if daysSince == 0 {
                // Already trained today — no change
            } else if daysSince == 1 {
                // Consecutive day — extend streak
                newStreak += 1
            } else {
                // Gap > 1 day — streak breaks. Start fresh.
                newStreak = 1
            }
        } else {
            // First workout ever
            newStreak = 1
        }

        newLongest = max(newLongest, newStreak)

        // Update profile
        try await supabase.from("profiles")
            .update([
                "current_streak": "\(newStreak)",
                "longest_streak": "\(newLongest)",
                "last_workout_date": dateFormatter.string(from: today)
            ])
            .eq("id", value: userId.uuidString)
            .execute()

        return (currentStreak: newStreak, longestStreak: newLongest)
    }

    // MARK: - Badges

    /// Fetches all badge definitions.
    func fetchAllBadges() async throws -> [Badge] {
        try await supabase.from("badges")
            .select()
            .order("category")
            .execute()
            .value
    }

    /// Fetches badges earned by a user.
    func fetchUserBadges(userId: UUID) async throws -> [UserBadge] {
        try await supabase.from("user_badges")
            .select("*, badges(*)")
            .eq("user_id", value: userId.uuidString)
            .order("earned_at", ascending: false)
            .execute()
            .value
    }

    /// Awards a badge to a user (idempotent — ON CONFLICT does nothing).
    func awardBadge(userId: UUID, badgeId: UUID) async throws {
        struct CreatePayload: Encodable {
            let user_id: String
            let badge_id: String
        }

        try await supabase.from("user_badges")
            .upsert(CreatePayload(
                user_id: userId.uuidString,
                badge_id: badgeId.uuidString
            ))
            .execute()
    }

    /// Checks and awards any newly earned badges based on current user stats.
    /// Call after workout completion to evaluate badge eligibility.
    func evaluateBadges(
        userId: UUID,
        totalSessions: Int,
        totalSets: Int,
        totalVolume: Double,
        currentStreak: Int,
        longestStreak: Int,
        totalPRs: Int,
        friendsCount: Int,
        fistBumpsGiven: Int
    ) async throws -> [Badge] {
        let allBadges = try await fetchAllBadges()
        let earnedBadges = try await fetchUserBadges(userId: userId)
        let earnedIds = Set(earnedBadges.map(\.badgeId))

        var newlyEarned: [Badge] = []

        for badge in allBadges {
            // Skip already earned
            guard !earnedIds.contains(badge.id) else { continue }

            let threshold = badge.requirementValue
            let met: Bool

            switch badge.requirementType {
            case "total_sets":
                met = totalSets >= threshold
            case "total_volume":
                met = Int(totalVolume) >= threshold
            case "total_sessions":
                met = totalSessions >= threshold
            case "streak_days":
                met = max(currentStreak, longestStreak) >= threshold
            case "total_prs":
                met = totalPRs >= threshold
            case "friends_count":
                met = friendsCount >= threshold
            case "fist_bumps_given":
                met = fistBumpsGiven >= threshold
            case "targets_hit", "dashboard_views":
                // These require separate tracking — skip for now
                met = false
            default:
                met = false
            }

            if met {
                try await awardBadge(userId: userId, badgeId: badge.id)
                newlyEarned.append(badge)
            }
        }

        return newlyEarned
    }

    // MARK: - Achievement Progress Data

    /// Fetches user stats needed to compute achievement progress.
    func fetchMilestoneProgressData(userId: UUID) async throws -> MilestoneProgressData {
        // Parallel queries
        async let sessionsTask: [ProgressCountRow] = supabase.from("workout_sessions")
            .select("count", head: false)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        async let prsTask: [ProgressCountRow] = supabase.from("personal_records")
            .select("count", head: false)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        async let profileTask: ProgressProfileRow = supabase.from("profiles")
            .select("current_streak, longest_streak")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        // Volume via RPC or aggregate
        async let volumeTask: [ProgressVolumeRow] = supabase.from("working_sets")
            .select("total_volume:weight.sum()")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        // Distinct exercises
        async let exercisesTask: [ProgressExerciseRow] = supabase.from("working_sets")
            .select("exercise_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let sessions = try await sessionsTask
        let prs = try await prsTask
        let profile = try await profileTask
        let volume = try await volumeTask
        let exercises = try await exercisesTask

        let uniqueExerciseIds = Set(exercises.map(\.exercise_id))

        // Fetch muscle groups for unique exercises
        var uniqueMuscleGroups = 0
        if !uniqueExerciseIds.isEmpty {
            let muscles: [ProgressMuscleRow] = try await supabase.from("exercises")
                .select("muscle_group")
                .in("id", values: uniqueExerciseIds.map(\.uuidString))
                .execute()
                .value
            uniqueMuscleGroups = Set(muscles.map(\.muscle_group)).count
        }

        return MilestoneProgressData(
            totalSessions: sessions.first?.count ?? 0,
            totalVolume: volume.first?.total_volume ?? 0,
            totalPRs: prs.first?.count ?? 0,
            bestStreak: profile.longest_streak,
            currentStreak: profile.current_streak,
            uniqueExercises: uniqueExerciseIds.count,
            uniqueMuscleGroups: uniqueMuscleGroups
        )
    }

    // MARK: - League Evaluation

    /// Evaluates league promotion/demotion based on weekly IQ ranking.
    /// Top 5 in tier promote up, bottom 5 demote down.
    func evaluateLeague(userId: UUID) async throws -> LeagueTier? {
        struct TierRow: Decodable { let league_tier: LeagueTier }

        let row: TierRow = try await supabase.from("profiles")
            .select("league_tier")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        let currentTier = row.league_tier

        // Fetch leaderboard for current tier
        let leaderboard = try await SocialService().fetchLeaderboard(tier: currentTier)
        guard let userIndex = leaderboard.firstIndex(where: { $0.id == userId }) else {
            return nil
        }

        let position = userIndex + 1 // 1-indexed
        let tiers = LeagueTier.allCases

        guard let tierIndex = tiers.firstIndex(of: currentTier) else { return nil }

        // Top 5 promote (if not already elite)
        if position <= 5 && tierIndex < tiers.count - 1 {
            let newTier = tiers[tierIndex + 1]
            try await SocialService().updateLeagueTier(userId: userId, tier: newTier)
            return newTier
        }

        // Bottom 5 demote (if not already bronze)
        if position > max(leaderboard.count - 5, 0) && tierIndex > 0 && leaderboard.count >= 10 {
            let newTier = tiers[tierIndex - 1]
            try await SocialService().updateLeagueTier(userId: userId, tier: newTier)
            return newTier
        }

        return nil
    }
}
