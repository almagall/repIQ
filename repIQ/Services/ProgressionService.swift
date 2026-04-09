import Foundation
import Supabase

struct ProgressionService: Sendable {

    // MARK: - Core Algorithm (e1RM-Based with RPE + Mesocycle Awareness)

    /// Calculates the progression target using estimated 1RM trends across recent sessions.
    /// Incorporates:
    /// - RPE + e1RM combined fatigue signals (Gap 7)
    /// - e1RM confidence weighting by rep range (Gap 5)
    /// - Mesocycle RPE progression (Gap 5 from RP framework)
    /// - Proactive deload ceiling (Gap 3)
    /// - Off-day escalation (Gap 6)
    func calculateTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        equipment: String,
        recentSessions: [[WorkoutSet]],
        repCap: Int? = nil,
        weeksSinceDeload: Int? = nil
    ) -> ProgressionTarget? {
        guard let latestSession = recentSessions.first, !latestSession.isEmpty else {
            return nil
        }

        // Bodyweight exercises use rep-only progression (no e1RM)
        let normalizedEquipment = equipment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedEquipment == "bodyweight" || normalizedEquipment == "body_weight" || normalizedEquipment == "body-weight" {
            return calculateBodyweightTarget(
                exerciseId: exerciseId,
                trainingMode: trainingMode,
                recentSessions: recentSessions,
                repCap: repCap,
                weeksSinceDeload: weeksSinceDeload
            )
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

        // e1RM confidence based on rep range (Gap 5: e1RM weighting by rep range)
        // Brzycki/Epley formulas are most accurate at 2-10 reps, error increases above 10
        let e1rmConfidence = e1rmConfidenceFactor(medReps: medReps)

        // RPE fatigue detection (Gap 7: RPE + e1RM combined signals)
        // If e1RM is stable but RPE is rising, that signals hidden fatigue
        let rpeFatigueDetected = detectRPEFatigue(recentSessions: recentSessions, targetRPE: targetRPE)

        // Mesocycle RPE offset (Gap 5: RPE progression across mesocycle)
        let mesocycleOffset = mesocycleRPEOffset(weeksSinceDeload: weeksSinceDeload)

        // Off-day detection: if latest best weight is far below recent best, use best e1RM
        let allRecentWorkingSets = recentSessions.flatMap { $0.filter { $0.setType == .working } }
        let bestRecentWeight = allRecentWorkingSets.map(\.weight).max() ?? medWeight
        let currentE1RM: Double

        if medWeight < bestRecentWeight * 0.90 {
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

        // Proactive deload ceiling (Gap 3): force deload after 7+ weeks regardless of trend
        if let weeks = weeksSinceDeload, weeks >= 7 {
            let deloadedE1RM = currentE1RM * 0.90
            decision = .deload
            tWeight = roundToIncrement(deloadedE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
            tRepsLow = repRange.lowerBound
            tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
            reasoning = "You've been training \(weeks) weeks without a deload. Scheduled recovery week to prevent overtraining and break through plateaus."

        } else if sessionE1RMs.count < 2 {
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

            // Off-day escalation (Gap 6): consecutive bad sessions → deload
            let consecutiveBadSessions = countConsecutiveBadSessions(recentSessions: recentSessions)

            if consecutiveBadSessions >= 2 {
                // Two or more consecutive >10% drops → real fatigue, not just off days
                let deloadedE1RM = currentE1RM * 0.90
                decision = .deload
                tWeight = roundToIncrement(deloadedE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "Performance has declined for multiple sessions. Deloading to allow recovery."

            } else if rpeFatigueDetected && percentChange >= -0.02 {
                // RPE rising at same e1RM → approaching fatigue ceiling (Gap 7)
                decision = .maintain
                tWeight = roundToIncrement(medWeight, increment)
                tRepsLow = medReps
                tRepsHigh = min(medReps, effectiveUpperBound)
                reasoning = "Weight is stable but effort is increasing. Maintaining to manage fatigue before it impacts performance."

            } else if medWeight < bestRecentWeight * 0.90 {
                // Single off-day
                decision = .maintain
                tWeight = roundToIncrement(currentE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "Last session was below your recent bests. Keeping targets at your proven capacity."

            } else if percentChange > 0.02 {
                // e1RM trending up — decide based on rep range confidence
                if e1rmConfidence >= 0.8 {
                    // High confidence (low rep range) — trust e1RM, increase weight
                    decision = .increaseWeight
                    tWeight = roundToIncrement(currentE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                    tRepsLow = repRange.lowerBound
                    tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                    reasoning = "Estimated 1RM is trending up. Prescribing weight for continued progress."
                } else {
                    // Lower confidence (high rep range) — favor rep progression first
                    if medReps < effectiveUpperBound {
                        decision = .increaseReps
                        tWeight = roundToIncrement(medWeight, increment)
                        tRepsLow = min(medReps + 1, effectiveUpperBound)
                        tRepsHigh = min(medReps + 2, effectiveUpperBound)
                        reasoning = "Getting stronger. Adding reps before increasing weight for this rep range."
                    } else {
                        decision = .increaseWeight
                        tWeight = roundToIncrement(currentE1RM * percentageOfE1RM(forReps: targetMidRep), increment)
                        tRepsLow = repRange.lowerBound
                        tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                        reasoning = "Hit top of rep range. Increasing weight and resetting reps."
                    }
                }

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
            estimatedOneRM: currentE1RM,
            mesocycleRPEOffset: mesocycleOffset,
            rpeFatigueDetected: rpeFatigueDetected,
            e1rmConfidence: e1rmConfidence
        )
    }

    // MARK: - Bodyweight Progression

    private func calculateBodyweightTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        recentSessions: [[WorkoutSet]],
        repCap: Int?,
        weeksSinceDeload: Int?
    ) -> ProgressionTarget? {
        guard let latestSession = recentSessions.first else { return nil }

        let latestWorkingSets = latestSession.filter { $0.setType == .working }
        guard !latestWorkingSets.isEmpty else { return nil }

        let repRange = trainingMode.repRange
        let effectiveUpperBound = min(repCap ?? repRange.upperBound, repRange.upperBound)
        let targetRPE = trainingMode.targetRPE

        let medReps = medianInt(latestWorkingSets.map(\.reps))
        let avgRPE = averageRPE(latestWorkingSets, default: targetRPE)
        let medWeight = median(latestWorkingSets.map(\.weight))

        let mesocycleOffset = mesocycleRPEOffset(weeksSinceDeload: weeksSinceDeload)

        let decision: ProgressionDecision
        let tRepsLow: Int
        let tRepsHigh: Int
        let reasoning: String

        // Proactive deload ceiling
        if let weeks = weeksSinceDeload, weeks >= 7 {
            decision = .deloadVolume
            tRepsLow = max(medReps - 2, repRange.lowerBound)
            tRepsHigh = max(medReps - 1, repRange.lowerBound)
            reasoning = "Scheduled recovery week after \(weeks) weeks of training."

        } else if recentSessions.count < 2 {
            decision = .maintain
            tRepsLow = medReps
            tRepsHigh = min(medReps, effectiveUpperBound)
            reasoning = "First session tracked. Repeat to establish a baseline."

        } else {
            let prevWorkingSets = recentSessions[1].filter { $0.setType == .working }
            let prevMedReps = prevWorkingSets.isEmpty ? medReps : medianInt(prevWorkingSets.map(\.reps))

            if medReps >= effectiveUpperBound {
                decision = .increaseWeight
                tRepsLow = repRange.lowerBound
                tRepsHigh = min(repRange.lowerBound + 2, effectiveUpperBound)
                reasoning = "You've reached \(effectiveUpperBound) reps. Consider adding external weight to keep progressing."

            } else if medReps > prevMedReps {
                decision = .increaseReps
                tRepsLow = min(medReps + 1, effectiveUpperBound)
                tRepsHigh = min(medReps + 2, effectiveUpperBound)
                reasoning = "Reps are improving. Keep pushing for more reps each session."

            } else if medReps == prevMedReps {
                decision = .increaseReps
                tRepsLow = min(medReps + 1, effectiveUpperBound)
                tRepsHigh = min(medReps + 1, effectiveUpperBound)
                reasoning = "Reps are holding steady. Aim for one more rep per set."

            } else {
                decision = .deloadVolume
                tRepsLow = max(medReps - 1, repRange.lowerBound)
                tRepsHigh = medReps
                reasoning = "Rep count has dropped. Consider reducing sets or taking a lighter session."
            }
        }

        return ProgressionTarget(
            exerciseId: exerciseId,
            trainingMode: trainingMode,
            targetWeight: medWeight,
            targetRepsLow: tRepsLow,
            targetRepsHigh: tRepsHigh,
            targetRPE: targetRPE,
            decision: decision,
            reasoning: reasoning,
            previousWeight: medWeight,
            previousReps: medReps,
            previousRPE: avgRPE,
            estimatedOneRM: 0,
            mesocycleRPEOffset: mesocycleOffset,
            rpeFatigueDetected: false,
            e1rmConfidence: 1.0
        )
    }

    // MARK: - RPE Fatigue Detection (Gap 7)

    /// Detects hidden fatigue: e1RM stable but RPE rising across sessions.
    /// If average RPE increased by 1+ point over 2-3 sessions at similar e1RM, fatigue is accumulating.
    private func detectRPEFatigue(recentSessions: [[WorkoutSet]], targetRPE: Double) -> Bool {
        guard recentSessions.count >= 2 else { return false }

        let sessionRPEs = recentSessions.prefix(3).map { session -> Double in
            averageRPE(session.filter { $0.setType == .working }, default: targetRPE)
        }

        // Check if RPE is trending up significantly
        guard sessionRPEs.count >= 2 else { return false }
        let latestRPE = sessionRPEs[0]
        let previousRPE = sessionRPEs.count >= 3
            ? (sessionRPEs[1] + sessionRPEs[2]) / 2.0
            : sessionRPEs[1]

        // Also check that e1RM isn't improving (if e1RM is rising, higher RPE is expected)
        let sessionE1RMs = recentSessions.prefix(3).compactMap { session -> Double? in
            let e1rm = bestE1RM(from: session)
            return e1rm > 0 ? e1rm : nil
        }

        guard sessionE1RMs.count >= 2 else { return false }
        let e1rmChange = (sessionE1RMs[0] - sessionE1RMs[1]) / sessionE1RMs[1]

        // Fatigue signal: RPE up by 1+ point AND e1RM flat or declining
        return (latestRPE - previousRPE) >= 1.0 && e1rmChange <= 0.02
    }

    // MARK: - e1RM Confidence by Rep Range (Gap 5)

    /// Returns a confidence factor for e1RM estimates based on the rep range used.
    /// Brzycki/Epley are most accurate at 2-10 reps. Above 10, error increases significantly.
    private func e1rmConfidenceFactor(medReps: Int) -> Double {
        switch medReps {
        case 1...5: return 1.0    // Highest confidence
        case 6...8: return 0.9    // Very reliable
        case 9...10: return 0.8   // Good reliability
        case 11...12: return 0.65 // Moderate — individual endurance varies
        case 13...15: return 0.5  // Lower — double progression preferred
        default: return 0.4       // 15+ reps — e1RM unreliable
        }
    }

    // MARK: - Mesocycle RPE Progression (Gap 5 from RP Framework)

    /// Returns an RPE offset based on weeks since last deload.
    /// Week 1-2: train at base RPE (offset 0)
    /// Week 3-4: train slightly harder (+0.5)
    /// Week 5-6: train harder (+1.0)
    /// Week 7+: should be deloading (handled by proactive deload ceiling)
    private func mesocycleRPEOffset(weeksSinceDeload: Int?) -> Double {
        guard let weeks = weeksSinceDeload else { return 0 }
        switch weeks {
        case 0...2: return 0      // Early mesocycle: base effort
        case 3...4: return 0.5    // Mid mesocycle: push slightly harder
        case 5...6: return 1.0    // Late mesocycle: peak effort before deload
        default: return 0         // Should be deloading
        }
    }

    // MARK: - Off-Day Escalation (Gap 6)

    /// Counts consecutive sessions where median weight dropped >10% from the best recent weight.
    private func countConsecutiveBadSessions(recentSessions: [[WorkoutSet]]) -> Int {
        guard recentSessions.count >= 2 else { return 0 }

        let allWorkingSets = recentSessions.flatMap { $0.filter { $0.setType == .working } }
        let bestRecentWeight = allWorkingSets.map(\.weight).max() ?? 0
        guard bestRecentWeight > 0 else { return 0 }

        var count = 0
        for session in recentSessions {
            let workingSets = session.filter { $0.setType == .working }
            let sessionMedWeight = median(workingSets.map(\.weight))
            if sessionMedWeight < bestRecentWeight * 0.90 {
                count += 1
            } else {
                break // Non-consecutive, stop counting
            }
        }
        return count
    }

    // MARK: - e1RM Helpers

    private func bestE1RM(from sets: [WorkoutSet]) -> Double {
        sets.filter { $0.setType == .working }
            .map(\.estimated1RM)
            .max() ?? 0
    }

    /// Returns the percentage of e1RM to use for a given rep target.
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
        return 0.73
    }

    // MARK: - PR Detection

    func detectPRs(
        exerciseId: UUID,
        userId: UUID,
        sessionId: UUID,
        completedSets: [WorkoutSet]
    ) async throws -> [PersonalRecord] {
        let workingSets = completedSets.filter { $0.setType == .working }
        guard !workingSets.isEmpty else { return [] }

        let maxWeight = workingSets.map(\.weight).max() ?? 0
        let maxReps = workingSets.map(\.reps).max() ?? 0
        let totalVolume = workingSets.reduce(0.0) { $0 + $1.volume }
        let maxEstimated1RM = workingSets.map(\.estimated1RM).max() ?? 0
        let bestWeightSet = workingSets.max(by: { $0.weight < $1.weight })

        let currentPRs = try await fetchCurrentPRs(userId: userId, exerciseId: exerciseId)
        let currentByType = Dictionary(uniqueKeysWithValues: currentPRs.map { ($0.recordType, $0) })

        var newPRs: [PersonalRecord] = []
        let now = Date()

        if maxWeight > (currentByType[.weight]?.value ?? 0) {
            newPRs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .weight, value: maxWeight,
                repsAtWeight: bestWeightSet?.reps, sessionId: sessionId,
                achievedAt: now, createdAt: now
            ))
        }

        if Double(maxReps) > (currentByType[.reps]?.value ?? 0) {
            newPRs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .reps, value: Double(maxReps),
                repsAtWeight: nil, sessionId: sessionId,
                achievedAt: now, createdAt: now
            ))
        }

        if totalVolume > (currentByType[.volume]?.value ?? 0) {
            newPRs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .volume, value: totalVolume,
                repsAtWeight: nil, sessionId: sessionId,
                achievedAt: now, createdAt: now
            ))
        }

        if maxEstimated1RM > (currentByType[.estimated1rm]?.value ?? 0) {
            newPRs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .estimated1rm, value: maxEstimated1RM,
                repsAtWeight: nil, sessionId: sessionId,
                achievedAt: now, createdAt: now
            ))
        }

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

    func shouldSuggestDeload(userId: UUID, templateId: UUID) async throws -> DeloadSuggestion? {
        let fiveWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -5, to: Date()) ?? Date()

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

        let rows: [ProgressionRow] = try await supabase.from("progression_log")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("exercise_id", values: exerciseIds.map(\.uuidString))
            .order("created_at", ascending: false)
            .execute()
            .value

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

    func fetchCurrentPRs(userId: UUID, exerciseId: UUID) async throws -> [PersonalRecord] {
        try await supabase.from("personal_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("exercise_id", value: exerciseId.uuidString)
            .execute()
            .value
    }

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
