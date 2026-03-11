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

        let sortedDates = workoutDates.sorted(by: >)
        let lastWorkoutDate = sortedDates.first

        // Calculate current streak (walking backward from today)
        let today = calendar.startOfDay(for: Date())
        var currentStreak = 0
        var checkDate = today
        var gapUsed = false

        // Allow today or yesterday to start counting
        if !workoutDates.contains(checkDate) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate),
               workoutDates.contains(yesterday) {
                checkDate = yesterday
                gapUsed = true
            } else {
                // No recent workout, streak is 0
                let bestStreak = calculateBestStreak(dates: workoutDates, calendar: calendar)
                return StreakData(currentStreak: 0, bestStreak: bestStreak, lastWorkoutDate: lastWorkoutDate)
            }
        }

        while true {
            if workoutDates.contains(checkDate) {
                currentStreak += 1
                gapUsed = false
            } else if !gapUsed {
                // Allow one rest day gap
                gapUsed = true
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        let bestStreak = calculateBestStreak(dates: workoutDates, calendar: calendar)

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
    private func calculateBestStreak(dates: Set<Date>, calendar: Calendar) -> Int {
        guard !dates.isEmpty else { return 0 }
        let sorted = dates.sorted()

        var bestStreak = 1
        var currentStreak = 1
        var gapUsed = false

        for i in 1..<sorted.count {
            let daysBetween = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0

            if daysBetween == 1 {
                currentStreak += 1
                gapUsed = false
            } else if daysBetween == 2 && !gapUsed {
                // Allow one rest day gap
                currentStreak += 1
                gapUsed = true
            } else {
                bestStreak = max(bestStreak, currentStreak)
                currentStreak = 1
                gapUsed = false
            }
        }

        return max(bestStreak, currentStreak)
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
