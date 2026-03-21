import Foundation
import Supabase

struct ProgressionService: Sendable {

    // MARK: - Core Algorithm (e1RM-Based)

    /// Calculates the progression target using estimated 1RM trends across recent sessions.
    /// Uses the Epley formula (weight × (1 + reps/30)) to compute e1RM from the best working set,
    /// then prescribes weight as a percentage of e1RM for the target rep range.
    func calculateTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        equipment: String,
        recentSessions: [[WorkoutSet]],
        repCap: Int? = nil
    ) -> ProgressionTarget? {
        guard let latestSession = recentSessions.first, !latestSession.isEmpty else {
            return nil
        }

        let repRange = trainingMode.repRange
        let effectiveUpperBound = min(repCap ?? repRange.upperBound, repRange.upperBound)
        let targetRPE = trainingMode.targetRPE
        let increment = weightIncrement(for: equipment)

        let latestWorkingSets = latestSession.filter { $0.setType == .working }
        guard !latestWorkingSets.isEmpty else { return nil }

        // Previous session stats for display
        let medWeight = median(latestWorkingSets.map(\.weight))
        let medReps = medianInt(latestWorkingSets.map(\.reps))
        let avgRPE = averageRPE(latestWorkingSets, default: targetRPE)

        // Compute e1RM per session
        let sessionE1RMs = recentSessions.compactMap { session -> Double? in
            let e1rm = bestE1RM(from: session)
            return e1rm > 0 ? e1rm : nil
        }

        guard let latestE1RM = sessionE1RMs.first else { return nil }

        // Off-day detection: if latest best weight is far below recent best, use best e1RM
        let allRecentWorkingSets = recentSessions.flatMap { $0.filter { $0.setType == .working } }
        let bestRecentWeight = allRecentWorkingSets.map(\.weight).max() ?? medWeight
        let currentE1RM: Double

        if medWeight < bestRecentWeight * 0.90 {
            // Off-day: use best recent e1RM instead of the poor session
            currentE1RM = sessionE1RMs.max() ?? latestE1RM
        } else {
            currentE1RM = latestE1RM
        }

        // Target rep midpoint for percentage lookup
        let targetMidRep = (repRange.lowerBound + effectiveUpperBound) / 2

        // Determine trend and make decision
        let decision: ProgressionDecision
        let tWeight: Double
        let tRepsLow: Int
        let tRepsHigh: Int
        let reasoning: String

        if sessionE1RMs.count < 2 {
            // Only 1 session — maintain (repeat what they did)
            decision = .maintain
            tWeight = roundToIncrement(medWeight, increment)
            tRepsLow = medReps
            tRepsHigh = min(medReps, effectiveUpperBound)
            reasoning = "First session tracked. Repeat to establish a baseline."

        } else {
            let previousE1RM: Double
            if sessionE1RMs.count >= 3 {
                previousE1RM = (sessionE1RMs[1] + sessionE1RMs[2]) / 2.0
            } else {
                previousE1RM = sessionE1RMs[1]
            }

            let percentChange = (currentE1RM - previousE1RM) / previousE1RM

            if medWeight < bestRecentWeight * 0.90 {
                // Off-day override
                decision = .maintain
                tWeight = roundToIncrement(currentE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "Last session was below your recent bests. Keeping targets at your proven capacity."

            } else if percentChange > 0.02 {
                // e1RM trending up — increase weight
                decision = .increaseWeight
                tWeight = roundToIncrement(currentE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "Estimated 1RM is trending up. Prescribing weight for continued progress."

            } else if percentChange >= -0.02 {
                // e1RM flat — increase reps at same weight
                decision = .increaseReps
                tWeight = roundToIncrement(medWeight, increment)
                tRepsLow = min(medReps + 1, effectiveUpperBound)
                tRepsHigh = min(medReps + 2, effectiveUpperBound)
                reasoning = "Strength is stable. Aim for more reps to drive adaptation."

            } else {
                // e1RM declining — deload
                let deloadedE1RM = currentE1RM * 0.90
                decision = .deload
                tWeight = roundToIncrement(deloadedE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "Estimated 1RM has declined. Reducing load to rebuild."
            }
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
            previousRPE: avgRPE,
            estimatedOneRM: currentE1RM
        )
    }

    // MARK: - e1RM Helpers

    /// Returns the highest estimated 1RM from working sets in a session.
    private func bestE1RM(from sets: [WorkoutSet]) -> Double {
        sets.filter { $0.setType == .working }
            .map(\.estimated1RM)
            .max() ?? 0
    }

    /// Returns the percentage of e1RM to use for a given rep target.
    /// Interpolates between anchor points: 3→90%, 5→85%, 8→78%, 10→73%, 12→68%, 15→63%.
    private func percentageOfE1RM(forReps reps: Int) -> Double {
        let anchors: [(reps: Int, pct: Double)] = [
            (1, 1.00), (3, 0.90), (5, 0.85), (8, 0.78),
            (10, 0.73), (12, 0.68), (15, 0.63), (20, 0.55)
        ]

        if reps <= anchors.first!.reps { return anchors.first!.pct }
        if reps >= anchors.last!.reps { return anchors.last!.pct }

        for i in 0..<(anchors.count - 1) {
            let low = anchors[i]
            let high = anchors[i + 1]
            if reps >= low.reps && reps <= high.reps {
                let t = Double(reps - low.reps) / Double(high.reps - low.reps)
                return low.pct + t * (high.pct - low.pct)
            }
        }
        return 0.73 // fallback
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

    // MARK: - Proactive Deload Suggestion

    struct DeloadSuggestion {
        let sessionCount: Int
        let weeksSinceLastDeload: Int?
    }

    /// Checks whether the user should consider a deload week based on training volume
    /// and time since last deload. Suggests if 12+ sessions in 5 weeks with no deload.
    func shouldSuggestDeload(userId: UUID, templateId: UUID) async throws -> DeloadSuggestion? {
        let fiveWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -5, to: Date()) ?? Date()

        // Count completed sessions for this template in the last 5 weeks
        struct SessionRow: Decodable { let id: UUID }
        let sessions: [SessionRow] = try await supabase.from("workout_sessions")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("template_id", value: templateId.uuidString)
            .eq("status", value: "completed")
            .gte("completed_at", value: ISO8601DateFormatter().string(from: fiveWeeksAgo))
            .execute()
            .value

        guard sessions.count >= 12 else { return nil }

        // Check if any deload decision was made in the last 5 weeks
        struct DeloadRow: Decodable { let created_at: String }
        let deloads: [DeloadRow] = try await supabase.from("progression_log")
            .select("created_at")
            .eq("user_id", value: userId.uuidString)
            .eq("decision", value: "deload")
            .gte("created_at", value: ISO8601DateFormatter().string(from: fiveWeeksAgo))
            .limit(1)
            .execute()
            .value

        if !deloads.isEmpty { return nil }

        // Calculate weeks since last deload (if any)
        let lastDeloads: [DeloadRow] = try await supabase.from("progression_log")
            .select("created_at")
            .eq("user_id", value: userId.uuidString)
            .eq("decision", value: "deload")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        var weeksSince: Int? = nil
        if let lastDeload = lastDeloads.first,
           let date = ISO8601DateFormatter().date(from: lastDeload.created_at) {
            weeksSince = Calendar.current.dateComponents([.weekOfYear], from: date, to: Date()).weekOfYear
        }

        return DeloadSuggestion(sessionCount: sessions.count, weeksSinceLastDeload: weeksSince)
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
            let estimated_1rm: Double?
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
            reasoning: target.reasoning,
            estimated_1rm: target.estimatedOneRM
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
            let estimated_1rm: Double?
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
                previousRPE: row.previous_rpe,
                estimatedOneRM: row.estimated_1rm
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
        Self.weightIncrement(for: equipment)
    }

    /// Public static accessor so per-set target logic can use equipment-specific increments.
    static func weightIncrement(for equipment: String) -> Double {
        switch equipment {
        case "barbell", "smith_machine": return AppConstants.WeightIncrements.barbellLbs
        case "dumbbell": return AppConstants.WeightIncrements.dumbbellLbs
        case "cable", "machine": return AppConstants.WeightIncrements.cableLbs
        case "bodyweight": return 0.0
        default: return AppConstants.WeightIncrements.barbellLbs
        }
    }

    private func roundToIncrement(_ weight: Double, _ increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded(.down) * increment
    }
}
