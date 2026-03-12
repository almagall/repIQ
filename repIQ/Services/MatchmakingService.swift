import Foundation
import Supabase

/// Smart matchmaking: finds lifters with similar training style, experience, lifts, and frequency.
struct MatchmakingService: Sendable {

    private let analyticsService = AnalyticsService()

    // MARK: - Profile Preferences

    /// Updates the user's matchmaking preferences on their profile.
    func updatePreferences(
        userId: UUID,
        trainingStyle: TrainingStyle?,
        experienceLevel: ExperienceLevel?,
        preferredFrequency: Int?,
        gymName: String?
    ) async throws {
        struct Payload: Encodable {
            let training_style: String?
            let experience_level: String?
            let preferred_frequency: Int?
            let gym_name: String?
        }

        try await supabase.from("profiles")
            .update(Payload(
                training_style: trainingStyle?.rawValue,
                experience_level: experienceLevel?.rawValue,
                preferred_frequency: preferredFrequency,
                gym_name: gymName
            ))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Find Matches

    /// Finds compatible training partners from all users (not already friends).
    func findMatches(userId: UUID, existingFriendIds: [UUID], limit: Int = 20) async throws -> [MatchmakingResult] {
        // 1. Fetch current user's profile
        let myProfile: SocialProfile = try await supabase.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        // 2. Fetch potential matches (exclude self and existing friends)
        let excludeIds = [userId] + existingFriendIds
        let candidates: [SocialProfile] = try await supabase.from("profiles")
            .select()
            .not("id", operator: .in, value: excludeIds.map(\.uuidString))
            .not("privacy_level", operator: .eq, value: "private")
            .limit(100)
            .execute()
            .value

        // 3. Fetch user's exercise history for comparison
        let myExerciseIds = try await fetchUserExerciseIds(userId: userId)

        // 4. Score each candidate
        var results: [MatchmakingResult] = []
        for candidate in candidates {
            let result = scoreCandidate(
                myProfile: myProfile,
                myExerciseIds: myExerciseIds,
                candidate: candidate
            )
            if result.compatibilityScore > 0.2 {
                results.append(result)
            }
        }

        // 5. Sort by compatibility score, return top N
        results.sort { $0.compatibilityScore > $1.compatibilityScore }
        return Array(results.prefix(limit))
    }

    // MARK: - Progression Race

    /// Fetches E1RM history for two users on the same exercise for side-by-side comparison.
    func fetchProgressionRace(
        userId: UUID,
        friendId: UUID,
        exerciseId: UUID,
        exerciseName: String
    ) async throws -> ProgressionRaceData {
        async let myHistory = analyticsService.fetchExerciseHistory(userId: userId, exerciseId: exerciseId)
        async let friendHistory = analyticsService.fetchExerciseHistory(userId: friendId, exerciseId: exerciseId)

        let (my, friend) = try await (myHistory, friendHistory)

        let mySnapshots = my.map { RaceSnapshot(id: $0.id, date: $0.date, estimated1RM: $0.estimated1RM) }
        let friendSnapshots = friend.map { RaceSnapshot(id: $0.id, date: $0.date, estimated1RM: $0.estimated1RM) }

        let myGain = calculateWeeklyGain(snapshots: mySnapshots)
        let friendGain = calculateWeeklyGain(snapshots: friendSnapshots)

        return ProgressionRaceData(
            exerciseName: exerciseName,
            exerciseId: exerciseId,
            mySnapshots: mySnapshots,
            friendSnapshots: friendSnapshots,
            myCurrentE1RM: mySnapshots.last?.estimated1RM ?? 0,
            friendCurrentE1RM: friendSnapshots.last?.estimated1RM ?? 0,
            myWeeklyGain: myGain,
            friendWeeklyGain: friendGain
        )
    }

    // MARK: - Milestones

    /// Evaluates and awards milestones based on current user stats.
    func evaluateMilestones(
        userId: UUID,
        totalSessions: Int,
        totalVolume: Double,
        currentStreak: Int,
        longestStreak: Int,
        accountCreatedAt: Date?
    ) async throws -> [UserMilestone] {
        // Fetch already-earned milestones
        let existing: [UserMilestone] = try await supabase.from("user_milestones")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let earnedTypes = Set(existing.map(\.milestoneType))
        var newMilestones: [UserMilestone] = []

        // Session milestones
        let sessionMilestones: [(MilestoneType, Int)] = [
            (.sessions100, 100), (.sessions250, 250), (.sessions500, 500), (.sessions1000, 1000)
        ]
        for (type, threshold) in sessionMilestones {
            if totalSessions >= threshold && !earnedTypes.contains(type) {
                let milestone = try await awardMilestone(userId: userId, type: type,
                    data: MilestoneData(totalSessions: totalSessions))
                newMilestones.append(milestone)
            }
        }

        // Streak milestones (use longest streak)
        let streakMilestones: [(MilestoneType, Int)] = [
            (.streak30, 30), (.streak90, 90), (.streak180, 180), (.streak365, 365)
        ]
        let bestStreak = max(currentStreak, longestStreak)
        for (type, threshold) in streakMilestones {
            if bestStreak >= threshold && !earnedTypes.contains(type) {
                let milestone = try await awardMilestone(userId: userId, type: type,
                    data: MilestoneData(streakDays: bestStreak))
                newMilestones.append(milestone)
            }
        }

        // Volume milestones
        let volumeMilestones: [(MilestoneType, Double)] = [
            (.volume100k, 100_000), (.volume500k, 500_000), (.volume1m, 1_000_000)
        ]
        for (type, threshold) in volumeMilestones {
            if totalVolume >= threshold && !earnedTypes.contains(type) {
                let milestone = try await awardMilestone(userId: userId, type: type,
                    data: MilestoneData(totalVolume: totalVolume))
                newMilestones.append(milestone)
            }
        }

        // Anniversary milestones
        if let created = accountCreatedAt {
            let yearsSince = Calendar.current.dateComponents([.year], from: created, to: Date()).year ?? 0
            if yearsSince >= 1 && !earnedTypes.contains(.yearAnniversary) {
                let milestone = try await awardMilestone(userId: userId, type: .yearAnniversary, data: nil)
                newMilestones.append(milestone)
            }
            if yearsSince >= 2 && !earnedTypes.contains(.twoYearAnniversary) {
                let milestone = try await awardMilestone(userId: userId, type: .twoYearAnniversary, data: nil)
                newMilestones.append(milestone)
            }
        }

        return newMilestones
    }

    /// Fetches all milestones for a user.
    func fetchMilestones(userId: UUID) async throws -> [UserMilestone] {
        try await supabase.from("user_milestones")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("achieved_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches recent milestones from friends for celebration.
    func fetchFriendMilestones(friendIds: [UUID], limit: Int = 20) async throws -> [UserMilestone] {
        guard !friendIds.isEmpty else { return [] }
        return try await supabase.from("user_milestones")
            .select()
            .in("user_id", values: friendIds.map(\.uuidString))
            .order("achieved_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Private Helpers

    private func awardMilestone(userId: UUID, type: MilestoneType, data: MilestoneData?) async throws -> UserMilestone {
        struct InsertPayload: Encodable {
            let user_id: String
            let milestone_type: String
            let data: MilestoneData?
        }

        let result: UserMilestone = try await supabase.from("user_milestones")
            .insert(InsertPayload(
                user_id: userId.uuidString,
                milestone_type: type.rawValue,
                data: data
            ))
            .select()
            .single()
            .execute()
            .value

        return result
    }

    private func fetchUserExerciseIds(userId: UUID) async throws -> Set<UUID> {
        struct ExerciseRow: Decodable {
            let exercise_id: UUID
        }

        let rows: [ExerciseRow] = try await supabase.from("workout_sets")
            .select("exercise_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.exercise_id))
    }

    private func scoreCandidate(
        myProfile: SocialProfile,
        myExerciseIds: Set<UUID>,
        candidate: SocialProfile
    ) -> MatchmakingResult {
        var score: Double = 0
        var reasons: [String] = []
        var styleMatch = false
        var levelMatch = false
        var freqMatch = false

        // Training style match (30% weight)
        if let myStyle = myProfile.trainingStyle, let theirStyle = candidate.trainingStyle {
            if myStyle == theirStyle {
                score += 0.30
                styleMatch = true
                reasons.append("Same training style: \(myStyle.capitalized)")
            } else {
                score += 0.10
            }
        }

        // Experience level match (25% weight)
        if let myLevel = myProfile.experienceLevel, let theirLevel = candidate.experienceLevel {
            if myLevel == theirLevel {
                score += 0.25
                levelMatch = true
                reasons.append("Same experience level: \(myLevel.capitalized)")
            } else {
                // Adjacent levels still get partial credit
                let levels = ["beginner", "intermediate", "advanced", "elite"]
                if let myIdx = levels.firstIndex(of: myLevel),
                   let theirIdx = levels.firstIndex(of: theirLevel),
                   abs(myIdx - theirIdx) == 1 {
                    score += 0.15
                    reasons.append("Similar experience level")
                }
            }
        }

        // Frequency match (20% weight)
        if let myFreq = myProfile.preferredFrequency, let theirFreq = candidate.preferredFrequency {
            if abs(myFreq - theirFreq) <= 1 {
                score += 0.20
                freqMatch = true
                reasons.append("Similar training frequency")
            }
        }

        // Gym match (15% weight)
        if let myGym = myProfile.gymName, let theirGym = candidate.gymName,
           !myGym.isEmpty, !theirGym.isEmpty,
           myGym.lowercased() == theirGym.lowercased() {
            score += 0.15
            reasons.append("Same gym: \(myGym)")
        }

        // Active user bonus (10% weight)
        if let lastWorkout = candidate.lastWorkoutDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastWorkout, to: Date()).day ?? 999
            if daysSince <= 7 {
                score += 0.10
                reasons.append("Active this week")
            }
        }

        if reasons.isEmpty {
            reasons.append("Potential training partner")
        }

        return MatchmakingResult(
            id: candidate.id,
            profile: candidate,
            compatibilityScore: min(score, 1.0),
            reasons: reasons,
            sharedExercises: [],
            trainingStyleMatch: styleMatch,
            experienceLevelMatch: levelMatch,
            frequencyMatch: freqMatch
        )
    }

    private func calculateWeeklyGain(snapshots: [RaceSnapshot]) -> Double {
        guard snapshots.count >= 2 else { return 0 }

        let sorted = snapshots.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return 0 }

        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: first.date, to: last.date).weekOfYear ?? 1)
        return (last.estimated1RM - first.estimated1RM) / Double(weeks)
    }
}
