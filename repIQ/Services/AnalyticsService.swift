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
