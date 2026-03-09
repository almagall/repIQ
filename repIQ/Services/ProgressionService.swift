import Foundation
import Supabase

struct ProgressionService: Sendable {

    // MARK: - Core Algorithm

    /// Calculates the progression target for an exercise based on recent performance.
    /// Returns nil if there's no data to base a decision on.
    func calculateTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        equipment: String,
        recentSessions: [[WorkoutSet]]
    ) -> ProgressionTarget? {
        // Need at least 1 session of data
        guard let latestSession = recentSessions.first, !latestSession.isEmpty else {
            return nil
        }

        let repRange = trainingMode.repRange
        let targetRPE = trainingMode.targetRPE
        let increment = weightIncrement(for: equipment)

        // Analyze latest session
        let latestWorkingSets = latestSession.filter { $0.setType == .working }
        guard !latestWorkingSets.isEmpty else { return nil }

        let medWeight = median(latestWorkingSets.map(\.weight))
        let medReps = medianInt(latestWorkingSets.map(\.reps))
        let avgRPE = averageRPE(latestWorkingSets, default: targetRPE)

        // Off-day detection: compare against best of last 3 sessions
        let allRecentWorkingSets = recentSessions.flatMap { $0.filter { $0.setType == .working } }
        let bestRecentWeight = allRecentWorkingSets.map(\.weight).max() ?? medWeight

        if medWeight < bestRecentWeight * 0.90 {
            // Off-day detected — maintain at proven capacity
            return ProgressionTarget(
                exerciseId: exerciseId,
                trainingMode: trainingMode,
                targetWeight: bestRecentWeight,
                targetRepsLow: repRange.lowerBound,
                targetRepsHigh: min(repRange.lowerBound + 2, repRange.upperBound),
                targetRPE: targetRPE,
                decision: .maintain,
                reasoning: "Last session was below your recent bests. Keeping targets at your proven capacity.",
                previousWeight: medWeight,
                previousReps: medReps,
                previousRPE: avgRPE
            )
        }

        // Count sessions where median reps were below the rep range
        let sessionsBelow = recentSessions.filter { session in
            let working = session.filter { $0.setType == .working }
            guard !working.isEmpty else { return false }
            return medianInt(working.map(\.reps)) < repRange.lowerBound
        }.count

        // Apply decision tree
        let decision: ProgressionDecision
        let tWeight: Double
        let tRepsLow: Int
        let tRepsHigh: Int
        let reasoning: String

        if medReps >= repRange.upperBound && avgRPE <= targetRPE {
            // Hit top of rep range at manageable effort → increase weight
            decision = .increaseWeight
            tWeight = medWeight + increment
            tRepsLow = repRange.lowerBound
            tRepsHigh = min(repRange.lowerBound + 2, repRange.upperBound)
            reasoning = "Hit top of rep range at manageable effort. Adding weight."

        } else if medReps >= repRange.lowerBound && avgRPE <= targetRPE {
            // Within range, manageable effort → increase reps
            decision = .increaseReps
            tWeight = medWeight
            tRepsLow = min(medReps + 1, repRange.upperBound)
            tRepsHigh = min(medReps + 2, repRange.upperBound)
            reasoning = "Good performance. Aim for 1–2 more reps."

        } else if medReps >= repRange.lowerBound && avgRPE > targetRPE {
            // Within range but high effort → maintain
            decision = .maintain
            tWeight = medWeight
            tRepsLow = medReps
            tRepsHigh = medReps
            reasoning = "Reps are there but effort is high. Repeat to build capacity."

        } else if medReps < repRange.lowerBound {
            // Below range
            if sessionsBelow >= 2 {
                // Stalling — deload
                decision = .deload
                tWeight = roundToIncrement(medWeight * 0.90, increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, repRange.upperBound)
                reasoning = "Struggling with target reps. Reducing weight to rebuild."
            } else {
                // One-off miss — maintain
                decision = .maintain
                tWeight = medWeight
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, repRange.upperBound)
                reasoning = "Missed target reps. Keep weight and aim for range."
            }

        } else {
            // Fallback — maintain
            decision = .maintain
            tWeight = medWeight
            tRepsLow = medReps
            tRepsHigh = medReps
            reasoning = "Maintain current performance."
        }

        return ProgressionTarget(
            exerciseId: exerciseId,
            trainingMode: trainingMode,
            targetWeight: tWeight,
            targetRepsLow: tRepsLow,
            targetRepsHigh: tRepsHigh,
            targetRPE: targetRPE,
            decision: decision,
            reasoning: reasoning,
            previousWeight: medWeight,
            previousReps: medReps,
            previousRPE: avgRPE
        )
    }

    // MARK: - PR Detection

    /// Detects new personal records from completed working sets.
    /// Returns only NEW PRs (where the value exceeds the current record or no record exists).
    func detectPRs(
        exerciseId: UUID,
        userId: UUID,
        sessionId: UUID,
        completedSets: [WorkoutSet]
    ) async throws -> [PersonalRecord] {
        let workingSets = completedSets.filter { $0.setType == .working }
        guard !workingSets.isEmpty else { return [] }

        // Calculate potential records from this session
        let maxWeight = workingSets.map(\.weight).max() ?? 0
        let maxReps = workingSets.map(\.reps).max() ?? 0
        let totalVolume = workingSets.reduce(0.0) { $0 + $1.volume }
        let maxEstimated1RM = workingSets.map(\.estimated1RM).max() ?? 0
        let bestWeightSet = workingSets.max(by: { $0.weight < $1.weight })

        // Fetch current records
        let currentPRs = try await fetchCurrentPRs(userId: userId, exerciseId: exerciseId)
        let currentByType = Dictionary(uniqueKeysWithValues: currentPRs.map { ($0.recordType, $0) })

        var newPRs: [PersonalRecord] = []
        let now = Date()

        // Weight PR
        if maxWeight > (currentByType[.weight]?.value ?? 0) {
            let pr = PersonalRecord(
                id: UUID(),
                userId: userId,
                exerciseId: exerciseId,
                recordType: .weight,
                value: maxWeight,
                repsAtWeight: bestWeightSet?.reps,
                sessionId: sessionId,
                achievedAt: now,
                createdAt: now
            )
            newPRs.append(pr)
        }

        // Reps PR
        if Double(maxReps) > (currentByType[.reps]?.value ?? 0) {
            let pr = PersonalRecord(
                id: UUID(),
                userId: userId,
                exerciseId: exerciseId,
                recordType: .reps,
                value: Double(maxReps),
                repsAtWeight: nil,
                sessionId: sessionId,
                achievedAt: now,
                createdAt: now
            )
            newPRs.append(pr)
        }

        // Volume PR
        if totalVolume > (currentByType[.volume]?.value ?? 0) {
            let pr = PersonalRecord(
                id: UUID(),
                userId: userId,
                exerciseId: exerciseId,
                recordType: .volume,
                value: totalVolume,
                repsAtWeight: nil,
                sessionId: sessionId,
                achievedAt: now,
                createdAt: now
            )
            newPRs.append(pr)
        }

        // Estimated 1RM PR
        if maxEstimated1RM > (currentByType[.estimated1rm]?.value ?? 0) {
            let pr = PersonalRecord(
                id: UUID(),
                userId: userId,
                exerciseId: exerciseId,
                recordType: .estimated1rm,
                value: maxEstimated1RM,
                repsAtWeight: nil,
                sessionId: sessionId,
                achievedAt: now,
                createdAt: now
            )
            newPRs.append(pr)
        }

        // Upsert new PRs
        for pr in newPRs {
            try await upsertPR(pr)
        }

        return newPRs
    }

    // MARK: - Persistence

    /// Saves a progression target to the progression_log table.
    func saveTarget(_ target: ProgressionTarget, userId: UUID) async throws {
        struct ProgressionLogEntry: Encodable {
            let id: UUID
            let user_id: String
            let exercise_id: String
            let training_mode: String
            let previous_weight: Double?
            let previous_reps: Int?
            let previous_rpe: Double?
            let target_weight: Double
            let target_reps_low: Int
            let target_reps_high: Int
            let target_rpe: Double
            let decision: String
            let reasoning: String?
        }

        let entry = ProgressionLogEntry(
            id: UUID(),
            user_id: userId.uuidString,
            exercise_id: target.exerciseId.uuidString,
            training_mode: target.trainingMode.rawValue,
            previous_weight: target.previousWeight,
            previous_reps: target.previousReps,
            previous_rpe: target.previousRPE,
            target_weight: target.targetWeight,
            target_reps_low: target.targetRepsLow,
            target_reps_high: target.targetRepsHigh,
            target_rpe: target.targetRPE,
            decision: target.decision.rawValue,
            reasoning: target.reasoning
        )

        try await supabase.from("progression_log")
            .insert(entry)
            .execute()
    }

    /// Fetches the latest progression target for each exercise.
    func fetchLatestTargets(userId: UUID, exerciseIds: [UUID]) async throws -> [UUID: ProgressionTarget] {
        guard !exerciseIds.isEmpty else { return [:] }

        struct ProgressionRow: Decodable {
            let exercise_id: String
            let training_mode: String
            let target_weight: Double
            let target_reps_low: Int
            let target_reps_high: Int
            let target_rpe: Double
            let decision: String
            let reasoning: String?
            let previous_weight: Double?
            let previous_reps: Int?
            let previous_rpe: Double?
        }

        // Fetch latest target per exercise by ordering by created_at DESC
        // We fetch all recent entries and group client-side (simpler than complex SQL)
        let rows: [ProgressionRow] = try await supabase.from("progression_log")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("exercise_id", values: exerciseIds.map(\.uuidString))
            .order("created_at", ascending: false)
            .execute()
            .value

        // Take the first (most recent) entry per exercise
        var result: [UUID: ProgressionTarget] = [:]
        for row in rows {
            guard let exerciseId = UUID(uuidString: row.exercise_id),
                  result[exerciseId] == nil else { continue }

            let trainingMode = TrainingMode(rawValue: row.training_mode) ?? .hypertrophy
            let decision = ProgressionDecision(rawValue: row.decision) ?? .maintain

            result[exerciseId] = ProgressionTarget(
                exerciseId: exerciseId,
                trainingMode: trainingMode,
                targetWeight: row.target_weight,
                targetRepsLow: row.target_reps_low,
                targetRepsHigh: row.target_reps_high,
                targetRPE: row.target_rpe,
                decision: decision,
                reasoning: row.reasoning ?? "",
                previousWeight: row.previous_weight,
                previousReps: row.previous_reps,
                previousRPE: row.previous_rpe
            )
        }

        return result
    }

    /// Fetches current personal records for an exercise.
    func fetchCurrentPRs(userId: UUID, exerciseId: UUID) async throws -> [PersonalRecord] {
        try await supabase.from("personal_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("exercise_id", value: exerciseId.uuidString)
            .execute()
            .value
    }

    /// Upserts a personal record (inserts or updates if a record for the same type already exists).
    func upsertPR(_ pr: PersonalRecord) async throws {
        struct PREntry: Encodable {
            let id: UUID
            let user_id: String
            let exercise_id: String
            let record_type: String
            let value: Double
            let reps_at_weight: Int?
            let session_id: String?
            let achieved_at: String
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let entry = PREntry(
            id: pr.id,
            user_id: pr.userId.uuidString,
            exercise_id: pr.exerciseId.uuidString,
            record_type: pr.recordType.rawValue,
            value: pr.value,
            reps_at_weight: pr.repsAtWeight,
            session_id: pr.sessionId?.uuidString,
            achieved_at: formatter.string(from: pr.achievedAt)
        )

        // Delete existing record for this user/exercise/type, then insert new one
        try await supabase.from("personal_records")
            .delete()
            .eq("user_id", value: pr.userId.uuidString)
            .eq("exercise_id", value: pr.exerciseId.uuidString)
            .eq("record_type", value: pr.recordType.rawValue)
            .execute()

        try await supabase.from("personal_records")
            .insert(entry)
            .execute()
    }

    // MARK: - Private Helpers

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    private func medianInt(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private func averageRPE(_ sets: [WorkoutSet], default defaultRPE: Double) -> Double {
        let recorded = sets.compactMap(\.rpe)
        guard !recorded.isEmpty else { return defaultRPE }
        return recorded.reduce(0, +) / Double(recorded.count)
    }

    private func weightIncrement(for equipment: String) -> Double {
        switch equipment {
        case "barbell", "smith_machine": return 5.0
        case "dumbbell": return 5.0
        case "cable", "machine": return 5.0
        case "bodyweight": return 0.0
        default: return 5.0
        }
    }

    private func roundToIncrement(_ weight: Double, _ increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded(.down) * increment
    }
}
