import Foundation
import Supabase

struct AnalyticsService: Sendable {

    private let workoutService = WorkoutService()
    private let exerciseService = ExerciseLibraryService()

    // MARK: - Weekly Volume Trend

    /// Returns weekly volume summaries for the past N weeks, ordered oldest → newest.
    func fetchWeeklyVolumeTrend(userId: UUID, weeks: Int = 8) async throws -> [WeeklyVolumeSummary] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fetch sessions in the date range
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .order("completed_at", ascending: true)
            .execute()
            .value

        guard !sessions.isEmpty else {
            return buildEmptyWeeks(from: startDate, count: weeks)
        }

        // Fetch all sets for these sessions
        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)

        // Group sets by session
        var setsBySession: [UUID: [WorkoutSet]] = [:]
        for set in allSets {
            setsBySession[set.sessionId, default: []].append(set)
        }

        // Build week buckets
        var weekBuckets: [Date: (volume: Double, sessions: Int)] = [:]
        for session in sessions {
            let date = session.completedAt ?? session.startedAt
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            let sessionVolume = (setsBySession[session.id] ?? [])
                .filter { $0.setType == .working }
                .reduce(0.0) { $0 + $1.volume }
            weekBuckets[weekStart, default: (0, 0)].volume += sessionVolume
            weekBuckets[weekStart, default: (0, 0)].sessions += 1
        }

        // Fill in empty weeks
        var results: [WeeklyVolumeSummary] = []
        var current = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate
        let now = Date()
        while current <= now {
            let bucket = weekBuckets[current]
            results.append(WeeklyVolumeSummary(
                weekStart: current,
                totalVolume: bucket?.volume ?? 0,
                sessionCount: bucket?.sessions ?? 0
            ))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }

        return results
    }

    // MARK: - Muscle Group Distribution

    /// Returns muscle group volume distribution for the past N days.
    func fetchMuscleGroupDistribution(userId: UUID, days: Int = 30) async throws -> [MuscleGroupVolume] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fetch recent sessions
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else { return [] }

        // Fetch all sets
        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let workingSets = allSets.filter { $0.setType == .working }

        guard !workingSets.isEmpty else { return [] }

        // Fetch exercises to get muscle groups
        let exerciseIds = Array(Set(workingSets.map(\.exerciseId)))
        let exercises = try await fetchExercisesFull(ids: exerciseIds)
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        // Aggregate by muscle group
        var groupVolume: [String: (volume: Double, sets: Int)] = [:]
        for set in workingSets {
            let group = exerciseMap[set.exerciseId]?.muscleGroup ?? "other"
            groupVolume[group, default: (0, 0)].volume += set.volume
            groupVolume[group, default: (0, 0)].sets += 1
        }

        let totalVolume = groupVolume.values.reduce(0.0) { $0 + $1.volume }
        guard totalVolume > 0 else { return [] }

        return groupVolume.map { group, data in
            let muscleGroup = MuscleGroup(rawValue: group)
            return MuscleGroupVolume(
                muscleGroup: group,
                displayName: muscleGroup?.displayName ?? group.capitalized,
                volume: data.volume,
                percentage: (data.volume / totalVolume) * 100,
                setCount: data.sets
            )
        }
        .sorted { $0.volume > $1.volume }
    }

    // MARK: - Exercise History

    /// Returns per-session snapshots for a specific exercise, ordered oldest → newest.
    func fetchExerciseHistory(userId: UUID, exerciseId: UUID) async throws -> [ExerciseSessionSnapshot] {
        // Fetch all completed sessions
        let sessions = try await workoutService.fetchAllSessions(userId: userId)
        guard !sessions.isEmpty else { return [] }

        // Fetch all sets for this exercise across all sessions
        let allSets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select()
            .in("session_id", values: sessions.map(\.id.uuidString))
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("set_type", value: "working")
            .order("set_number")
            .execute()
            .value

        // Group by session
        var setsBySession: [UUID: [WorkoutSet]] = [:]
        for set in allSets {
            setsBySession[set.sessionId, default: []].append(set)
        }

        // Build session map for dates
        let sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })

        // Build snapshots
        var snapshots: [ExerciseSessionSnapshot] = []
        for (sessionId, sets) in setsBySession {
            guard let session = sessionMap[sessionId], !sets.isEmpty else { continue }
            let date = session.completedAt ?? session.startedAt

            let bestWeight = sets.map(\.weight).max() ?? 0
            let bestReps = sets.map(\.reps).max() ?? 0
            let totalVolume = sets.reduce(0.0) { $0 + $1.volume }
            let rpeValues = sets.compactMap(\.rpe)
            let avgRPE = rpeValues.isEmpty ? nil : rpeValues.reduce(0, +) / Double(rpeValues.count)
            let estimated1RM = sets.map(\.estimated1RM).max() ?? 0

            snapshots.append(ExerciseSessionSnapshot(
                id: sessionId,
                date: date,
                bestWeight: bestWeight,
                bestReps: bestReps,
                totalVolume: totalVolume,
                avgRPE: avgRPE,
                estimated1RM: estimated1RM,
                setCount: sets.count
            ))
        }

        return snapshots.sorted { $0.date < $1.date }
    }

    // MARK: - Recent PRs

    /// Fetches recent personal records with exercise names.
    func fetchRecentPRs(userId: UUID, limit: Int = 10) async throws -> [(record: PersonalRecord, exerciseName: String)] {
        let records: [PersonalRecord] = try await supabase.from("personal_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("achieved_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        guard !records.isEmpty else { return [] }

        let exerciseIds = Array(Set(records.map(\.exerciseId)))
        let names = try await exerciseService.fetchExercisesByIds(exerciseIds)

        return records.map { record in
            (record: record, exerciseName: names[record.exerciseId] ?? "Unknown")
        }
    }

    // MARK: - Training Frequency

    /// Returns daily workout counts for the past N weeks. One entry per day.
    func fetchTrainingFrequency(userId: UUID, weeks: Int = 12) async throws -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        // Count sessions per calendar day
        var dayCounts: [Date: Int] = [:]
        for session in sessions {
            let date = session.completedAt ?? session.startedAt
            let dayStart = calendar.startOfDay(for: date)
            dayCounts[dayStart, default: 0] += 1
        }

        // Build full day range
        var results: [(date: Date, count: Int)] = []
        var current = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: Date())
        while current <= today {
            results.append((date: current, count: dayCounts[current] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return results
    }

    // MARK: - Streak Calculation

    /// Calculates current and best training streaks.
    /// A streak day = any day with at least one completed session.
    /// Allows a 1-day gap (rest day) within a streak.
    func fetchCurrentStreak(userId: UUID) async throws -> StreakData {
        let sessions = try await workoutService.fetchAllSessions(userId: userId)
        guard !sessions.isEmpty else {
            return StreakData(currentStreak: 0, bestStreak: 0, lastWorkoutDate: nil)
        }

        let calendar = Calendar.current

        // Get unique workout dates (as start-of-day)
        let workoutDates: Set<Date> = Set(sessions.compactMap { session in
            let date = session.completedAt ?? session.startedAt
            return calendar.startOfDay(for: date)
        })

        let lastWorkoutDate = workoutDates.max()

        // Weekly streak: count consecutive weeks with at least 1 workout
        // Group workout dates into week-of-year identifiers
        let workoutWeeks: Set<String> = Set(workoutDates.map { date in
            let year = calendar.component(.yearForWeekOfYear, from: date)
            let week = calendar.component(.weekOfYear, from: date)
            return "\(year)-\(week)"
        })

        // Walk backward from current week
        let today = Date()
        var currentStreak = 0
        var checkWeekDate = today

        // Check current week first
        let currentWeekId = "\(calendar.component(.yearForWeekOfYear, from: today))-\(calendar.component(.weekOfYear, from: today))"

        // If no workout this week, check if last week had one (grace: current week is still in progress)
        if !workoutWeeks.contains(currentWeekId) {
            if let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: today) {
                let lastWeekId = "\(calendar.component(.yearForWeekOfYear, from: lastWeekDate))-\(calendar.component(.weekOfYear, from: lastWeekDate))"
                if workoutWeeks.contains(lastWeekId) {
                    checkWeekDate = lastWeekDate
                } else {
                    let bestStreak = calculateBestWeeklyStreak(workoutWeeks: workoutWeeks, calendar: calendar, latestDate: lastWorkoutDate ?? today)
                    return StreakData(currentStreak: 0, bestStreak: bestStreak, lastWorkoutDate: lastWorkoutDate)
                }
            }
        }

        // Count consecutive weeks backward
        while true {
            let weekId = "\(calendar.component(.yearForWeekOfYear, from: checkWeekDate))-\(calendar.component(.weekOfYear, from: checkWeekDate))"
            if workoutWeeks.contains(weekId) {
                currentStreak += 1
                guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeekDate) else { break }
                checkWeekDate = prevWeek
            } else {
                break
            }
        }

        let bestStreak = calculateBestWeeklyStreak(workoutWeeks: workoutWeeks, calendar: calendar, latestDate: lastWorkoutDate ?? today)

        return StreakData(
            currentStreak: currentStreak,
            bestStreak: max(currentStreak, bestStreak),
            lastWorkoutDate: lastWorkoutDate
        )
    }

    // MARK: - Milestone Progress

    /// Fetches aggregate data needed to evaluate milestones.
    func fetchMilestoneProgress(userId: UUID) async throws -> MilestoneProgressData {
        let sessions = try await workoutService.fetchAllSessions(userId: userId)

        // Total volume: fetch all sets
        var totalVolume: Double = 0
        var uniqueExerciseIds: Set<UUID> = []

        if !sessions.isEmpty {
            let sessionIds = sessions.map(\.id)
            let allSets = try await fetchSetsForSessions(sessionIds)
            let workingSets = allSets.filter { $0.setType == .working }
            totalVolume = workingSets.reduce(0.0) { $0 + $1.volume }
            uniqueExerciseIds = Set(workingSets.map(\.exerciseId))
        }

        // PR count
        let prCount = try await fetchTotalPRCount(userId: userId)

        // Streak
        let streak = try await fetchCurrentStreak(userId: userId)

        // Unique muscle groups
        var uniqueMuscleGroups = 0
        if !uniqueExerciseIds.isEmpty {
            let exercises = try await fetchExercisesFull(ids: Array(uniqueExerciseIds))
            uniqueMuscleGroups = Set(exercises.map(\.muscleGroup)).count
        }

        return MilestoneProgressData(
            totalSessions: sessions.count,
            totalVolume: totalVolume,
            totalPRs: prCount,
            bestStreak: streak.bestStreak,
            currentStreak: streak.currentStreak,
            uniqueExercises: uniqueExerciseIds.count,
            uniqueMuscleGroups: uniqueMuscleGroups
        )
    }

    // MARK: - Effective Reps Summary

    /// Returns effective (stimulating) reps per muscle group for the past N days.
    /// Uses RPE data to estimate how many reps per set were near failure.
    func fetchEffectiveRepsSummary(userId: UUID, days: Int = 30) async throws -> [EffectiveRepsSummary] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else { return [] }

        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let workingSets = allSets.filter { $0.setType == .working }
        guard !workingSets.isEmpty else { return [] }

        let exerciseIds = Array(Set(workingSets.map(\.exerciseId)))
        let exercises = try await fetchExercisesFull(ids: exerciseIds)
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        // Aggregate effective reps by muscle group
        var groupData: [String: (effectiveReps: Int, totalReps: Int, sets: Int)] = [:]
        for set in workingSets {
            let group = exerciseMap[set.exerciseId]?.muscleGroup ?? "other"
            let effective = CompoundSynergistMap.effectiveReps(reps: set.reps, rpe: set.rpe)
            groupData[group, default: (0, 0, 0)].effectiveReps += effective
            groupData[group, default: (0, 0, 0)].totalReps += set.reps
            groupData[group, default: (0, 0, 0)].sets += 1
        }

        return groupData.map { group, data in
            let muscleGroup = MuscleGroup(rawValue: group)
            return EffectiveRepsSummary(
                muscleGroup: group,
                displayName: muscleGroup?.displayName ?? group.capitalized,
                effectiveReps: data.effectiveReps,
                totalReps: data.totalReps,
                totalSets: data.sets
            )
        }
        .sorted { $0.totalSets > $1.totalSets }
    }

    // MARK: - Fractional Muscle Distribution

    /// Like fetchMuscleGroupDistribution but adds 0.5x synergist credit for compound exercises.
    func fetchFractionalMuscleDistribution(userId: UUID, days: Int = 30) async throws -> [MuscleGroupVolume] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else { return [] }

        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let workingSets = allSets.filter { $0.setType == .working }
        guard !workingSets.isEmpty else { return [] }

        let exerciseIds = Array(Set(workingSets.map(\.exerciseId)))
        let exercises = try await fetchExercisesFull(ids: exerciseIds)
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        // Aggregate with synergist credit
        var groupVolume: [String: (volume: Double, sets: Int)] = [:]
        for set in workingSets {
            guard let exercise = exerciseMap[set.exerciseId] else { continue }
            let primary = exercise.muscleGroup
            let setVolume = set.volume

            // Full credit to primary
            groupVolume[primary, default: (0, 0)].volume += setVolume
            groupVolume[primary, default: (0, 0)].sets += 1

            // Synergist credit for compound exercises
            let synergistList = CompoundSynergistMap.synergistGroups(primary: primary, isCompound: exercise.isCompound)
            for synergist in synergistList {
                groupVolume[synergist, default: (0, 0)].volume += setVolume * CompoundSynergistMap.synergistMultiplier
            }
        }

        let totalVolume = groupVolume.values.reduce(0.0) { $0 + $1.volume }
        guard totalVolume > 0 else { return [] }

        return groupVolume.map { group, data in
            let muscleGroup = MuscleGroup(rawValue: group)
            return MuscleGroupVolume(
                muscleGroup: group,
                displayName: muscleGroup?.displayName ?? group.capitalized,
                volume: data.volume,
                percentage: (data.volume / totalVolume) * 100,
                setCount: data.sets
            )
        }
        .sorted { $0.volume > $1.volume }
    }

    // MARK: - Average RPE

    /// Returns average RPE across all working sets in the past N days. Nil if no RPE data.
    func fetchAverageRPE(userId: UUID, days: Int = 14) async throws -> Double? {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else { return nil }

        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let rpeValues = allSets
            .filter { $0.setType == .working }
            .compactMap(\.rpe)

        guard !rpeValues.isEmpty else { return nil }
        return rpeValues.reduce(0, +) / Double(rpeValues.count)
    }

    // MARK: - Push/Pull Balance

    /// Returns push vs pull volume balance for the past N days.
    func fetchPushPullBalance(userId: UUID, days: Int = 30) async throws -> PushPullBalance {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return PushPullBalance(pushVolume: 0, pullVolume: 0, pushSets: 0, pullSets: 0)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else {
            return PushPullBalance(pushVolume: 0, pullVolume: 0, pushSets: 0, pullSets: 0)
        }

        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let workingSets = allSets.filter { $0.setType == .working }

        let exerciseIds = Array(Set(workingSets.map(\.exerciseId)))
        let exercises = try await fetchExercisesFull(ids: exerciseIds)
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        var pushVolume: Double = 0
        var pullVolume: Double = 0
        var pushSets = 0
        var pullSets = 0

        for set in workingSets {
            let group = exerciseMap[set.exerciseId]?.muscleGroup ?? ""
            if PushPullBalance.pushGroups.contains(group) {
                pushVolume += set.volume
                pushSets += 1
            } else if PushPullBalance.pullGroups.contains(group) {
                pullVolume += set.volume
                pullSets += 1
            }
        }

        return PushPullBalance(
            pushVolume: pushVolume,
            pullVolume: pullVolume,
            pushSets: pushSets,
            pullSets: pullSets
        )
    }

    // MARK: - Consistency Score

    /// Computes a 0–100 consistency score from multiple training factors.
    func fetchConsistencyScore(userId: UUID, weeks: Int = 8) async throws -> ConsistencyScore {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return ConsistencyScore(overall: 0, frequencyScore: 0, volumeStabilityScore: 0, streakScore: 0, recencyScore: 0)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .order("completed_at", ascending: true)
            .execute()
            .value

        // 1. Frequency Score (40%) — sessions per week vs target of 4
        let targetSessionsPerWeek = 4.0
        let totalWeeks = max(1.0, Double(weeks))
        let sessionsPerWeek = Double(sessions.count) / totalWeeks
        let frequencyScore = min(1.0, sessionsPerWeek / targetSessionsPerWeek)

        // 2. Volume Stability (25%) — coefficient of variation of weekly volumes
        var volumeStabilityScore: Double = 0
        if sessions.count >= 2 {
            let allSets = try await fetchSetsForSessions(sessions.map(\.id))
            var weeklyVolumes: [Date: Double] = [:]
            for session in sessions {
                let date = session.completedAt ?? session.startedAt
                guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
                let sessionVolume = allSets
                    .filter { $0.sessionId == session.id && $0.setType == .working }
                    .reduce(0.0) { $0 + $1.volume }
                weeklyVolumes[weekStart, default: 0] += sessionVolume
            }

            let volumes = Array(weeklyVolumes.values).filter { $0 > 0 }
            if volumes.count >= 2 {
                let mean = volumes.reduce(0, +) / Double(volumes.count)
                let variance = volumes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(volumes.count)
                let cv = mean > 0 ? sqrt(variance) / mean : 1.0
                // Lower CV = more stable. CV of 0 = perfect, CV > 0.5 = very unstable
                volumeStabilityScore = max(0, 1.0 - (cv * 2.0))
            }
        }

        // 3. Streak Score (20%) — current streak normalized
        let streak = try await fetchCurrentStreak(userId: userId)
        let streakScore = min(1.0, Double(streak.currentStreak) / 14.0) // 14-day streak = full score

        // 4. Recency Score (15%) — days since last workout
        var recencyScore: Double = 0
        if let lastWorkout = streak.lastWorkoutDate {
            let daysSince = calendar.dateComponents([.day], from: lastWorkout, to: Date()).day ?? 30
            // 0 days = 1.0, 7+ days = 0.0
            recencyScore = max(0, 1.0 - (Double(daysSince) / 7.0))
        }

        // Weighted composite
        let overall = Int(round(
            (frequencyScore * 40.0) +
            (volumeStabilityScore * 25.0) +
            (streakScore * 20.0) +
            (recencyScore * 15.0)
        ))

        return ConsistencyScore(
            overall: min(100, max(0, overall)),
            frequencyScore: frequencyScore,
            volumeStabilityScore: volumeStabilityScore,
            streakScore: streakScore,
            recencyScore: recencyScore
        )
    }

    // MARK: - Volume Landmark Data

    /// Returns volume landmark comparison for each muscle group over the past 7 days (1 week).
    func fetchVolumeLandmarkData(userId: UUID) async throws -> [VolumeLandmarkData] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: formatter.string(from: startDate))
            .execute()
            .value

        guard !sessions.isEmpty else { return [] }

        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchSetsForSessions(sessionIds)
        let workingSets = allSets.filter { $0.setType == .working }
        guard !workingSets.isEmpty else { return [] }

        let exerciseIds = Array(Set(workingSets.map(\.exerciseId)))
        let exercises = try await fetchExercisesFull(ids: exerciseIds)
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        // Count sets per muscle group
        var setsByGroup: [String: Int] = [:]
        for set in workingSets {
            let group = exerciseMap[set.exerciseId]?.muscleGroup ?? "other"
            setsByGroup[group, default: 0] += 1
        }

        return setsByGroup.compactMap { group, setCount in
            guard group != "other" else { return nil }
            let landmark = VolumeLandmarkReference.landmark(for: group)
            let muscleGroup = MuscleGroup(rawValue: group)
            return VolumeLandmarkData(
                muscleGroup: group,
                displayName: muscleGroup?.displayName ?? group.capitalized,
                currentWeeklySets: setCount,
                mev: landmark.mev,
                mav: landmark.mavRange,
                mrv: landmark.mrv
            )
        }
        .sorted { $0.currentWeeklySets > $1.currentWeeklySets }
    }

    // MARK: - Strength Prediction (for ExerciseProgressView)

    /// Computes a 4-week E1RM projection using simple linear regression on session snapshots.
    static func predictStrength(from snapshots: [ExerciseSessionSnapshot]) -> StrengthPrediction? {
        guard snapshots.count >= 3 else { return nil }

        let e1rmValues = snapshots.map(\.estimated1RM)
        guard let currentE1RM = e1rmValues.last, currentE1RM > 0 else { return nil }

        // X = days from first snapshot, Y = E1RM
        let firstDate = snapshots.first!.date
        let xs = snapshots.map { snapshot in
            Double(Calendar.current.dateComponents([.day], from: firstDate, to: snapshot.date).day ?? 0)
        }
        let ys = e1rmValues

        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator // lbs per day
        let intercept = (sumY - slope * sumX) / n

        // R² for confidence
        let meanY = sumY / n
        let ssRes = zip(xs, ys).reduce(0) { $0 + pow($1.1 - (slope * $1.0 + intercept), 2) }
        let ssTot = ys.reduce(0) { $0 + pow($1 - meanY, 2) }
        let rSquared = ssTot > 0 ? max(0, 1.0 - (ssRes / ssTot)) : 0

        // Project 28 days (4 weeks) from last data point
        let lastX = xs.last ?? 0
        let projectedE1RM = slope * (lastX + 28.0) + intercept
        let weeklyGain = slope * 7.0

        return StrengthPrediction(
            currentE1RM: currentE1RM,
            projectedE1RM: max(0, projectedE1RM),
            weeklyGainRate: weeklyGain,
            confidence: rSquared
        )
    }

    // MARK: - Monthly Stats

    /// Fetches stats for the current calendar month: workouts, PRs, sets, average RPE.
    /// Used by the Progress tab header to give users an at-a-glance "how was my month".
    func fetchMonthlyStats(userId: UUID) async throws -> MonthlyStats {
        let calendar = Calendar.current
        let now = Date()

        // Current month bounds
        guard let currentInterval = calendar.dateInterval(of: .month, for: now) else {
            return MonthlyStats(workouts: 0, prCount: 0, totalSets: 0, avgRPE: nil, previousMonth: nil)
        }

        // Previous month bounds (last day of previous month → 1 day before current start)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previousInterval = calendar.dateInterval(of: .month, for: previousMonthDate)

        // Fetch in parallel
        async let currentTask = fetchStatsForRange(
            userId: userId,
            start: currentInterval.start,
            end: currentInterval.end
        )
        async let previousTask: (workouts: Int, prCount: Int, totalSets: Int, avgRPE: Double?)? = {
            guard let prev = previousInterval else { return nil }
            return try? await fetchStatsForRange(userId: userId, start: prev.start, end: prev.end)
        }()

        let current = try await currentTask
        let previous = await previousTask

        return MonthlyStats(
            workouts: current.workouts,
            prCount: current.prCount,
            totalSets: current.totalSets,
            avgRPE: current.avgRPE,
            previousMonth: previous.map {
                PreviousMonthStats(workouts: $0.workouts, prCount: $0.prCount, totalSets: $0.totalSets, avgRPE: $0.avgRPE)
            }
        )
    }

    /// Helper that fetches workouts/PRs/sets/RPE for an arbitrary date range.
    /// Used by `fetchMonthlyStats` to compute current and previous month in parallel.
    private func fetchStatsForRange(
        userId: UUID,
        start: Date,
        end: Date
    ) async throws -> (workouts: Int, prCount: Int, totalSets: Int, avgRPE: Double?) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)

        // Sessions completed in this range
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: startString)
            .lt("completed_at", value: endString)
            .execute()
            .value

        let workouts = sessions.count

        // PRs achieved in this range
        struct PRRow: Decodable { let id: UUID }
        let prRows: [PRRow] = (try? await supabase.from("personal_records")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .gte("achieved_at", value: startString)
            .lt("achieved_at", value: endString)
            .execute()
            .value) ?? []
        let prCount = prRows.count

        // Working sets logged in this range
        var totalSets = 0
        var rpeSum = 0.0
        var rpeCount = 0
        if !sessions.isEmpty {
            let sessionIds = sessions.map(\.id)
            let sets: [WorkoutSet] = (try? await supabase.from("workout_sets")
                .select()
                .in("session_id", values: sessionIds.map(\.uuidString))
                .eq("set_type", value: "working")
                .execute()
                .value) ?? []
            totalSets = sets.count
            for set in sets {
                if let rpe = set.rpe {
                    rpeSum += rpe
                    rpeCount += 1
                }
            }
        }
        let avgRPE = rpeCount > 0 ? rpeSum / Double(rpeCount) : nil

        return (workouts: workouts, prCount: prCount, totalSets: totalSets, avgRPE: avgRPE)
    }

    // MARK: - Last Workout Recap

    /// Fetches a lightweight summary of the user's most recent completed session.
    /// Used by the Last Workout recap card on the Progress tab. Returns nil if
    /// the user has no completed sessions.
    func fetchLastWorkoutRecap(userId: UUID) async throws -> LastWorkoutRecap? {
        // Most recent completed session
        let sessions: [WorkoutSession] = try await supabase.from("workout_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let session = sessions.first, let completedAt = session.completedAt else {
            return nil
        }

        // Sets for this session (working sets only for the volume calculation)
        let sets: [WorkoutSet] = (try? await supabase.from("workout_sets")
            .select()
            .eq("session_id", value: session.id.uuidString)
            .eq("set_type", value: "working")
            .execute()
            .value) ?? []

        let workingSets = sets.count
        let totalVolume = sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        // PR count for this session
        struct PRRow: Decodable { let id: UUID }
        let prRows: [PRRow] = (try? await supabase.from("personal_records")
            .select("id")
            .eq("session_id", value: session.id.uuidString)
            .execute()
            .value) ?? []

        // Resolve template + day names if present
        var templateName: String? = nil
        var dayName: String? = nil
        if let templateId = session.templateId {
            templateName = (try? await workoutService.fetchTemplateNames(ids: [templateId]))?[templateId]
        }
        if let dayId = session.workoutDayId {
            dayName = (try? await workoutService.fetchWorkoutDayNames(ids: [dayId]))?[dayId]
        }

        return LastWorkoutRecap(
            sessionId: session.id,
            templateName: templateName,
            dayName: dayName,
            completedAt: completedAt,
            durationSeconds: session.durationSeconds ?? 0,
            workingSets: workingSets,
            totalVolume: totalVolume,
            prCount: prRows.count
        )
    }

    // MARK: - Top Lifts Trajectory

    /// Fetches the user's top N most-frequently-logged exercises with their session snapshots
    /// and a computed velocity narrative. Used for the Progress tab hero card.
    ///
    /// Selection logic: prefers compound lifts (multi-joint movements with meaningful
    /// e1RM tracking) over isolation movements. A user's bench press progress matters
    /// more than their cable fly progress, even if the cable fly has more sessions.
    func fetchTopLiftsTrajectory(userId: UUID, limit: Int = 5) async throws -> [TopLiftTrajectory] {
        // Fetch all completed sessions
        let sessions = try await workoutService.fetchAllSessions(userId: userId)
        guard !sessions.isEmpty else { return [] }

        // Build session lookup maps
        let sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let sessionDayMap: [UUID: UUID?] = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.workoutDayId) })

        // Fetch all working sets across all sessions
        let sessionIds = sessions.map(\.id)
        let allSets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select()
            .in("session_id", values: sessionIds.map(\.uuidString))
            .eq("set_type", value: "working")
            .execute()
            .value
        guard !allSets.isEmpty else { return [] }

        // Composite key: (exerciseId, workoutDayId) — same exercise on different
        // workout days is tracked independently because fatigue context differs.
        struct ExerciseDayKey: Hashable {
            let exerciseId: UUID
            let workoutDayId: UUID? // nil for legacy sessions without a day
        }

        // Count unique sessions per exercise-day pair
        var sessionCountByKey: [ExerciseDayKey: Set<UUID>] = [:]
        for set in allSets {
            let dayId = sessionDayMap[set.sessionId] ?? nil
            let key = ExerciseDayKey(exerciseId: set.exerciseId, workoutDayId: dayId)
            sessionCountByKey[key, default: []].insert(set.sessionId)
        }

        // Need at least 2 sessions to be a meaningful trajectory candidate
        let candidateKeys = sessionCountByKey
            .filter { $0.value.count >= 2 }
            .keys
            .map { $0 }

        guard !candidateKeys.isEmpty else { return [] }

        // Collect unique exercise IDs for metadata lookup
        let uniqueExerciseIds = Array(Set(candidateKeys.map(\.exerciseId)))

        // Fetch exercise names + equipment + muscle groups + isCompound for ranking
        let exerciseNames: [UUID: String]
        let exerciseMuscles: [UUID: String]
        let exerciseIsCompound: [UUID: Bool]
        do {
            let (names, muscles, _, isCompound) = try await exerciseService
                .fetchExerciseDetails(uniqueExerciseIds)
            exerciseNames = names
            exerciseMuscles = muscles
            exerciseIsCompound = isCompound
        } catch {
            exerciseNames = [:]
            exerciseMuscles = [:]
            exerciseIsCompound = [:]
        }

        // Score each candidate: session count with 2x compound multiplier
        let scored = candidateKeys.map { key -> (ExerciseDayKey, Double) in
            let sessions = Double(sessionCountByKey[key]?.count ?? 0)
            let isCompound = exerciseIsCompound[key.exerciseId] ?? false
            let multiplier: Double = isCompound ? 2.0 : 1.0
            return (key, sessions * multiplier)
        }

        let topKeys = scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)

        guard !topKeys.isEmpty else { return [] }

        // Fetch workout day names for display
        let uniqueDayIds = Array(Set(topKeys.compactMap(\.workoutDayId)))
        let dayNames: [UUID: String]
        if !uniqueDayIds.isEmpty {
            dayNames = (try? await workoutService.fetchWorkoutDayNames(ids: uniqueDayIds)) ?? [:]
        } else {
            dayNames = [:]
        }

        // Build snapshots per exercise-day pair
        var trajectories: [TopLiftTrajectory] = []

        for key in topKeys {
            let exerciseSets = allSets.filter { set in
                set.exerciseId == key.exerciseId
                    && (sessionDayMap[set.sessionId] ?? nil) == key.workoutDayId
            }

            // Group by session
            var setsBySession: [UUID: [WorkoutSet]] = [:]
            for set in exerciseSets {
                setsBySession[set.sessionId, default: []].append(set)
            }

            // Build snapshots
            var snapshots: [ExerciseSessionSnapshot] = []
            for (sessionId, sets) in setsBySession {
                guard let session = sessionMap[sessionId], !sets.isEmpty else { continue }
                let date = session.completedAt ?? session.startedAt
                let bestWeight = sets.map(\.weight).max() ?? 0
                let bestReps = sets.map(\.reps).max() ?? 0
                let totalVolume = sets.reduce(0.0) { $0 + $1.volume }
                let rpeValues = sets.compactMap(\.rpe)
                let avgRPE = rpeValues.isEmpty ? nil : rpeValues.reduce(0, +) / Double(rpeValues.count)
                let estimated1RM = sets.map(\.estimated1RM).max() ?? 0
                snapshots.append(ExerciseSessionSnapshot(
                    id: sessionId,
                    date: date,
                    bestWeight: bestWeight,
                    bestReps: bestReps,
                    totalVolume: totalVolume,
                    avgRPE: avgRPE,
                    estimated1RM: estimated1RM,
                    setCount: sets.count
                ))
            }
            snapshots.sort { $0.date < $1.date }

            guard let last = snapshots.last else { continue }

            // 4-week strength projection (only show when the regression fit is
            // confident enough — false projections are worse than no projection).
            let rawProjection = AnalyticsService.predictStrength(from: snapshots)
            let projection: StrengthPrediction? = (rawProjection?.confidence ?? 0) >= 0.5 ? rawProjection : nil

            // Compute 4-week delta
            let fourWeeksAgo = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
            let priorSnapshot = snapshots.reversed().first(where: { $0.date <= fourWeeksAgo })
                ?? snapshots.first
            let priorE1RM = priorSnapshot?.estimated1RM ?? last.estimated1RM
            let delta = last.estimated1RM - priorE1RM
            let deltaPercent = priorE1RM > 0 ? (delta / priorE1RM) * 100 : 0

            // Compute velocity from recent vs older split
            let velocityStatus: VelocityStatus
            let weeklyPercent: Double
            if snapshots.count >= 4 {
                let splitIndex = max(snapshots.count - 3, 1)
                let older = Array(snapshots.prefix(splitIndex))
                let recent = Array(snapshots.suffix(from: splitIndex))
                let olderAvg = older.map(\.estimated1RM).reduce(0, +) / Double(older.count)
                let recentAvg = recent.map(\.estimated1RM).reduce(0, +) / Double(recent.count)
                guard olderAvg > 0 else {
                    velocityStatus = .maintaining
                    weeklyPercent = 0
                    trajectories.append(TopLiftTrajectory(
                        exerciseId: key.exerciseId,
                        exerciseName: exerciseNames[key.exerciseId] ?? "Exercise",
                        muscleGroup: exerciseMuscles[key.exerciseId] ?? "",
                        workoutDayId: key.workoutDayId,
                        dayName: key.workoutDayId.flatMap { dayNames[$0] },
                        sessionCount: sessionCountByKey[key]?.count ?? 0,
                        currentE1RM: last.estimated1RM,
                        fourWeekDelta: delta,
                        fourWeekDeltaPercent: deltaPercent,
                        velocityStatus: velocityStatus,
                        weeklyPercent: weeklyPercent,
                        narrative: TopLiftTrajectory.buildNarrative(
                            status: velocityStatus,
                            weeklyPercent: weeklyPercent,
                            deltaPercent: deltaPercent,
                            sessionCount: snapshots.count
                        ),
                        sparkline: snapshots.map(\.estimated1RM),
                        projection: projection
                    ))
                    continue
                }
                let percentChange = ((recentAvg - olderAvg) / olderAvg) * 100
                let daysSpan = max(1, Double(Calendar.current.dateComponents([.day], from: older.last!.date, to: recent.last!.date).day ?? 7))
                let weeksSpan = daysSpan / 7.0
                weeklyPercent = weeksSpan > 0 ? percentChange / weeksSpan : 0
                velocityStatus = VelocityStatus.from(weeklyPercent: weeklyPercent)
            } else {
                velocityStatus = .maintaining
                weeklyPercent = 0
            }

            let narrative = TopLiftTrajectory.buildNarrative(
                status: velocityStatus,
                weeklyPercent: weeklyPercent,
                deltaPercent: deltaPercent,
                sessionCount: snapshots.count
            )

            trajectories.append(TopLiftTrajectory(
                exerciseId: key.exerciseId,
                exerciseName: exerciseNames[key.exerciseId] ?? "Exercise",
                muscleGroup: exerciseMuscles[key.exerciseId] ?? "",
                workoutDayId: key.workoutDayId,
                dayName: key.workoutDayId.flatMap { dayNames[$0] },
                sessionCount: sessionCountByKey[key]?.count ?? 0,
                currentE1RM: last.estimated1RM,
                fourWeekDelta: delta,
                fourWeekDeltaPercent: deltaPercent,
                velocityStatus: velocityStatus,
                weeklyPercent: weeklyPercent,
                narrative: narrative,
                sparkline: snapshots.suffix(12).map(\.estimated1RM),
                projection: projection
            ))
        }

        return trajectories
    }

    // MARK: - Helpers

    /// Fetches sets for multiple sessions in a single query.
    private func fetchSetsForSessions(_ sessionIds: [UUID]) async throws -> [WorkoutSet] {
        guard !sessionIds.isEmpty else { return [] }

        // Supabase `in` can handle large arrays; chunk if needed
        let sets: [WorkoutSet] = try await supabase.from("workout_sets")
            .select()
            .in("session_id", values: sessionIds.map(\.uuidString))
            .execute()
            .value

        return sets
    }

    /// Fetches full Exercise objects by IDs.
    private func fetchExercisesFull(ids: [UUID]) async throws -> [Exercise] {
        guard !ids.isEmpty else { return [] }
        let exercises: [Exercise] = try await supabase.from("exercises")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return exercises
    }

    /// Counts total personal records for a user.
    private func fetchTotalPRCount(userId: UUID) async throws -> Int {
        let records: [PersonalRecord] = try await supabase.from("personal_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return records.count
    }

    /// Calculates the longest streak from a set of workout dates.
    private func calculateBestWeeklyStreak(workoutWeeks: Set<String>, calendar: Calendar, latestDate: Date) -> Int {
        guard !workoutWeeks.isEmpty else { return 0 }

        // Walk backward from the latest workout date week by week
        var bestStreak = 0
        var currentStreak = 0
        var checkDate = latestDate

        // Go back far enough to cover all data (52 weeks * 5 years max)
        for _ in 0..<260 {
            let weekId = "\(calendar.component(.yearForWeekOfYear, from: checkDate))-\(calendar.component(.weekOfYear, from: checkDate))"
            if workoutWeeks.contains(weekId) {
                currentStreak += 1
                bestStreak = max(bestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
            guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
            checkDate = prevWeek
        }

        return bestStreak
    }

    private func buildEmptyWeeks(from startDate: Date, count: Int) -> [WeeklyVolumeSummary] {
        let calendar = Calendar.current
        var results: [WeeklyVolumeSummary] = []
        var current = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate
        for _ in 0..<count {
            results.append(WeeklyVolumeSummary(weekStart: current, totalVolume: 0, sessionCount: 0))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }
        return results
    }
}
