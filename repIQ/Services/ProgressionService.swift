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
    /// - Parameter allowDeload: When false, every branch that would prescribe a
    ///   deload is suppressed and routed into normal progression instead — used
    ///   when the user is offered a deload and chooses to keep progressing.
    func calculateTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        equipment: String,
        recentSessions: [[WorkoutSet]],
        repCap: Int? = nil,
        weeksSinceDeload: Int? = nil,
        allowDeload: Bool = true
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
                weeksSinceDeload: weeksSinceDeload,
                allowDeload: allowDeload
            )
        }

        switch trainingMode {
        case .hypertrophy:
            return hypertrophyTarget(
                exerciseId: exerciseId, equipment: equipment,
                recentSessions: recentSessions, repCap: repCap,
                weeksSinceDeload: weeksSinceDeload, allowDeload: allowDeload
            )
        case .strength:
            return strengthTarget(
                exerciseId: exerciseId, equipment: equipment,
                recentSessions: recentSessions, repCap: repCap,
                weeksSinceDeload: weeksSinceDeload, allowDeload: allowDeload
            )
        }
    }

    // MARK: - Hypertrophy (Strict Double Progression)

    /// Rep-driven double progression. Weight advances by exactly one increment,
    /// and only when every working set reached the top of the rep range (strict
    /// trigger) or the hardest set still had 2+ reps in reserve (RPE early-bump).
    /// e1RM is deliberately NOT a decision input: the estimation formulas are
    /// unreliable in the 10-15 rep band, so progression follows actual reps
    /// against the range instead. (Replaced the prior e1RM-trend + confidence-gate
    /// model, which stalled weight whenever the median rep count sat below the cap
    /// and never credited beating the prescription — see branch strip-social-v1.)
    private func hypertrophyTarget(
        exerciseId: UUID,
        equipment: String,
        recentSessions: [[WorkoutSet]],
        repCap: Int?,
        weeksSinceDeload: Int?,
        allowDeload: Bool
    ) -> ProgressionTarget? {
        let mode = TrainingMode.hypertrophy
        let repRange = mode.repRange
        let bottom = repRange.lowerBound
        let top = min(repCap ?? repRange.upperBound, repRange.upperBound)
        let targetRPE = mode.targetRPE
        let increment = weightIncrement(for: equipment)

        guard let latestSession = recentSessions.first else { return nil }
        let working = latestSession.filter { $0.setType == .working }
        guard !working.isEmpty else { return nil }

        let workingWeight = median(working.map(\.weight))
        let medReps = medianInt(working.map(\.reps))
        let minReps = working.map(\.reps).min() ?? medReps
        let avgRPE = averageRPE(working, default: targetRPE)
        let hardestRPE = working.compactMap(\.rpe).max()
        let mesocycleOffset = mesocycleRPEOffset(weeksSinceDeload: weeksSinceDeload)
        // Kept only for summary/log display continuity — not a decision input.
        let currentE1RM = bestE1RM(from: latestSession)

        // The prescription is a SINGLE rep goal for the session (not a range). The
        // rep band (10..top) still lives on TrainingMode; the target is the one
        // number to hit this session, which increments week to week toward the top.
        func makeTarget(
            _ decision: ProgressionDecision,
            weight: Double, reps: Int, reasoning: String
        ) -> ProgressionTarget {
            let r = min(max(reps, 1), top)
            return ProgressionTarget(
                exerciseId: exerciseId, trainingMode: mode,
                targetWeight: roundToIncrement(weight, increment),
                targetRepsLow: r, targetRepsHigh: r,
                targetRPE: targetRPE, decision: decision, reasoning: reasoning,
                previousWeight: workingWeight, previousReps: medReps, previousRPE: avgRPE,
                estimatedOneRM: currentE1RM, mesocycleRPEOffset: mesocycleOffset,
                rpeFatigueDetected: false, e1rmConfidence: 1.0
            )
        }

        // Deload safety nets (weight-based; e1RM not needed here).
        if let weeks = weeksSinceDeload, weeks >= 7, allowDeload {
            return makeTarget(.deload, weight: workingWeight * 0.90, reps: bottom,
                reasoning: "You've trained \(weeks) weeks without a deload. Scheduled recovery week to prevent overtraining.")
        }
        if allowDeload, countConsecutiveBadSessions(recentSessions: recentSessions) >= 2 {
            return makeTarget(.deload, weight: workingWeight * 0.90, reps: bottom,
                reasoning: "Performance has declined for multiple sessions. Deloading to allow recovery.")
        }

        // Baseline: need 2 sessions of history before prescribing progression.
        guard recentSessions.count >= 2 else {
            return makeTarget(.maintain, weight: workingWeight, reps: min(medReps, top),
                reasoning: "First session tracked. Repeat to establish a baseline.")
        }

        // Single off-day: last session's weight far below recent best → hold at
        // proven capacity rather than progressing from a bad day.
        let bestRecentWeight = recentSessions
            .flatMap { $0.filter { $0.setType == .working } }
            .map(\.weight).max() ?? workingWeight
        if workingWeight < bestRecentWeight * 0.90 {
            return makeTarget(.maintain, weight: bestRecentWeight, reps: bottom,
                reasoning: "Last session was below your recent bests. Holding at your proven working weight.")
        }

        // Strict trigger: every working set reached the top of the range. Because
        // this tests the minimum, an over-cap session (e.g. 17 reps on a 15 cap)
        // also satisfies it — beating the top just earns the bump sooner, never a
        // larger-than-one-increment jump.
        if minReps >= top {
            return makeTarget(.increaseWeight, weight: workingWeight + increment, reps: bottom,
                reasoning: "You hit the top of the rep range on every set. Adding weight and resetting reps to the bottom of the range.")
        }
        // Missed the floor — hold weight and rebuild before progressing.
        if minReps < bottom {
            return makeTarget(.maintain, weight: workingWeight, reps: bottom,
                reasoning: "Last session fell below the rep range. Holding weight to rebuild.")
        }
        // RPE early-bump: the hardest set still left 3+ reps in reserve → add load
        // now rather than grinding up a wide range. The 3-RIR bar (vs the textbook
        // 2-RIR "add weight" trigger used for strength) is deliberately conservative
        // for hypertrophy: accumulating reps at a load is valuable stimulus, so only
        // skip ahead on load when there's a clear surplus. Only fires when RPE was
        // logged; absent RPE degrades cleanly to pure strict double progression.
        if let rpe = hardestRPE, rpe <= targetRPE - 3 {
            return makeTarget(.increaseWeight, weight: workingWeight + increment, reps: bottom,
                reasoning: "You had 3+ reps in reserve on your hardest set. Adding weight early.")
        }
        // In range, not yet all at top — add a rep. The weakest set (minReps) gates
        // the eventual weight bump, so the single target is one above it.
        return makeTarget(.increaseReps, weight: workingWeight, reps: min(minReps + 1, top),
            reasoning: "Getting stronger. Aim for \(min(minReps + 1, top)) reps on every set on your way to \(top).")
    }

    // MARK: - Strength (Load-Biased Double Progression on the Top Set)

    /// Load-driven progression using the heaviest working set (top of the ramp)
    /// as the reference. Weight advances when the top set reaches the top of the
    /// 3-5 rep range, or on an RPE early-bump. e1RM is a valid signal at 3-5 reps,
    /// so it sizes the jump (e.g. a 5->3 rep reset warrants more than one
    /// increment); a one-increment floor guarantees it never rounds backward.
    private func strengthTarget(
        exerciseId: UUID,
        equipment: String,
        recentSessions: [[WorkoutSet]],
        repCap: Int?,
        weeksSinceDeload: Int?,
        allowDeload: Bool
    ) -> ProgressionTarget? {
        let mode = TrainingMode.strength
        let repRange = mode.repRange
        let bottom = repRange.lowerBound
        let top = min(repCap ?? repRange.upperBound, repRange.upperBound)
        let targetRPE = mode.targetRPE
        let increment = weightIncrement(for: equipment)

        guard let latestSession = recentSessions.first else { return nil }
        let working = latestSession.filter { $0.setType == .working }
        guard let topSet = working.max(by: { $0.weight < $1.weight }) else { return nil }

        let topSetWeight = topSet.weight
        let topSetReps = topSet.reps
        let topSetRPE = topSet.rpe
        let medWeight = median(working.map(\.weight))
        let medReps = medianInt(working.map(\.reps))
        let avgRPE = averageRPE(working, default: targetRPE)
        let mesocycleOffset = mesocycleRPEOffset(weeksSinceDeload: weeksSinceDeload)

        let sessionE1RMs = recentSessions.compactMap { session -> Double? in
            let e = bestE1RM(from: session)
            return e > 0 ? e : nil
        }
        let latestE1RM = sessionE1RMs.first ?? topSetWeight
        let bestRecentTopWeight = recentSessions
            .flatMap { $0.filter { $0.setType == .working } }
            .map(\.weight).max() ?? topSetWeight
        let offDay = topSetWeight < bestRecentTopWeight * 0.90
        // On an off-day, size from the best recent e1RM, not the bad session.
        let currentE1RM = offDay ? (sessionE1RMs.max() ?? latestE1RM) : latestE1RM
        let e1rmConfidence = e1rmConfidenceFactor(medReps: medReps)
        let rpeFatigue = detectRPEFatigue(recentSessions: recentSessions, targetRPE: targetRPE)

        // Single rep goal for the session (the top set's target); ramp sets derive
        // their reps from it in perSetTarget.
        func makeTarget(
            _ decision: ProgressionDecision,
            weight: Double, reps: Int, reasoning: String
        ) -> ProgressionTarget {
            let r = min(max(reps, 1), top)
            return ProgressionTarget(
                exerciseId: exerciseId, trainingMode: mode,
                targetWeight: roundToIncrement(weight, increment),
                targetRepsLow: r, targetRepsHigh: r,
                targetRPE: targetRPE, decision: decision, reasoning: reasoning,
                previousWeight: medWeight, previousReps: medReps, previousRPE: avgRPE,
                estimatedOneRM: currentE1RM, mesocycleRPEOffset: mesocycleOffset,
                rpeFatigueDetected: rpeFatigue, e1rmConfidence: e1rmConfidence
            )
        }

        // Deload safety nets.
        if let weeks = weeksSinceDeload, weeks >= 7, allowDeload {
            return makeTarget(.deload, weight: currentE1RM * 0.90 * percentageOfE1RM(forReps: bottom), reps: bottom,
                reasoning: "You've trained \(weeks) weeks without a deload. Scheduled recovery week to prevent overtraining.")
        }
        if allowDeload, countConsecutiveBadSessions(recentSessions: recentSessions) >= 2 {
            return makeTarget(.deload, weight: currentE1RM * 0.90 * percentageOfE1RM(forReps: bottom), reps: bottom,
                reasoning: "Performance has declined for multiple sessions. Deloading to allow recovery.")
        }

        // Baseline.
        guard recentSessions.count >= 2 else {
            return makeTarget(.maintain, weight: topSetWeight, reps: min(topSetReps, top),
                reasoning: "First session tracked. Repeat to establish a baseline.")
        }

        // Single off-day: hold at proven top-set weight.
        if offDay {
            return makeTarget(.maintain, weight: bestRecentTopWeight, reps: bottom,
                reasoning: "Last session was below your recent bests. Holding at your proven top-set weight.")
        }

        // Weight jump sized from e1RM (valid at 3-5 reps), floored one increment
        // above the top set so it can never round backward.
        func bumpedWeight() -> Double {
            increaseWeightTarget(
                e1rmDerived: currentE1RM * percentageOfE1RM(forReps: bottom),
                anchorWeight: topSetWeight, increment: increment, rpeBonusIncrements: 0
            )
        }

        // Double progression on the top set.
        if topSetReps >= top {
            return makeTarget(.increaseWeight, weight: bumpedWeight(), reps: bottom,
                reasoning: "You hit the top of the rep range on your top set. Adding weight and resetting reps.")
        }
        if topSetReps < bottom {
            return makeTarget(.maintain, weight: topSetWeight, reps: bottom,
                reasoning: "Top set fell below the rep range. Holding weight to rebuild.")
        }
        if let rpe = topSetRPE, rpe <= targetRPE - 2 {
            return makeTarget(.increaseWeight, weight: bumpedWeight(), reps: bottom,
                reasoning: "You had 2+ reps in reserve on your top set. Adding weight early.")
        }
        return makeTarget(.increaseReps, weight: topSetWeight, reps: min(topSetReps + 1, top),
            reasoning: "Strength is building. Aim for \(min(topSetReps + 1, top)) on your top set before increasing weight.")
    }

    // MARK: - Bodyweight Progression

    private func calculateBodyweightTarget(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        recentSessions: [[WorkoutSet]],
        repCap: Int?,
        weeksSinceDeload: Int?,
        allowDeload: Bool
    ) -> ProgressionTarget? {
        guard let latestSession = recentSessions.first else { return nil }

        let latestWorkingSets = latestSession.filter { $0.setType == .working }
        guard !latestWorkingSets.isEmpty else { return nil }

        let repRange = trainingMode.repRange
        let bottom = repRange.lowerBound
        let top = min(repCap ?? repRange.upperBound, repRange.upperBound)
        let targetRPE = trainingMode.targetRPE

        let medReps = medianInt(latestWorkingSets.map(\.reps))
        let minReps = latestWorkingSets.map(\.reps).min() ?? medReps
        let avgRPE = averageRPE(latestWorkingSets, default: targetRPE)
        let medWeight = median(latestWorkingSets.map(\.weight))

        let mesocycleOffset = mesocycleRPEOffset(weeksSinceDeload: weeksSinceDeload)

        // Rep-only double progression: a SINGLE rep goal per session (no range),
        // mirroring the weighted path. Bodyweight can't shed load, so a decline
        // holds/reduces reps instead of dropping weight.
        func makeTarget(_ decision: ProgressionDecision, reps: Int, _ reasoning: String) -> ProgressionTarget {
            ProgressionTarget(
                exerciseId: exerciseId, trainingMode: trainingMode,
                targetWeight: medWeight,
                targetRepsLow: max(reps, 1), targetRepsHigh: max(reps, 1),
                targetRPE: targetRPE, decision: decision, reasoning: reasoning,
                previousWeight: medWeight, previousReps: medReps, previousRPE: avgRPE,
                estimatedOneRM: 0, mesocycleRPEOffset: mesocycleOffset,
                rpeFatigueDetected: false, e1rmConfidence: 1.0
            )
        }

        if let weeks = weeksSinceDeload, weeks >= 7, allowDeload {
            return makeTarget(.deloadVolume, reps: max(medReps - 2, bottom),
                "Scheduled recovery week after \(weeks) weeks of training.")
        }
        guard recentSessions.count >= 2 else {
            return makeTarget(.maintain, reps: min(medReps, top),
                "First session tracked. Repeat to establish a baseline.")
        }
        // Below the range floor — hold at current reps and rebuild (no load to shed).
        if minReps < bottom {
            return makeTarget(.maintain, reps: min(medReps, top),
                "Last session fell below the rep range. Holding to rebuild.")
        }
        let prevWorkingSets = recentSessions[1].filter { $0.setType == .working }
        let prevMedReps = prevWorkingSets.isEmpty ? medReps : medianInt(prevWorkingSets.map(\.reps))
        if minReps >= top {
            return makeTarget(.increaseWeight, reps: bottom,
                "You reached \(top) reps on every set. Add external weight to keep progressing.")
        }
        if medReps < prevMedReps, allowDeload {
            return makeTarget(.deloadVolume, reps: max(medReps - 1, bottom),
                "Rep count has dropped. Reduce volume or take a lighter session.")
        }
        // Improving, holding, or keeping-progressing after a dip → aim for one more.
        return makeTarget(.increaseReps, reps: min(minReps + 1, top),
            "Reps are progressing. Aim for \(min(minReps + 1, top)) on every set.")
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

    func saveTarget(_ target: ProgressionTarget, userId: UUID, workoutDayId: UUID? = nil) async throws {
        struct ProgressionLogEntry: Encodable {
            let id: UUID
            let user_id: String
            let exercise_id: String
            let workout_day_id: String?
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
            workout_day_id: workoutDayId?.uuidString,
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

    /// Fetches the most recent progression target for each exercise.
    /// When `workoutDayId` is provided, only entries tagged with that day are considered —
    /// keeping the same exercise on different days on independent progression histories.
    func fetchLatestTargets(
        userId: UUID,
        exerciseIds: [UUID],
        workoutDayId: UUID? = nil
    ) async throws -> [UUID: ProgressionTarget] {
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

        let rows: [ProgressionRow]
        if let workoutDayId {
            rows = try await supabase.from("progression_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("workout_day_id", value: workoutDayId.uuidString)
                .in("exercise_id", values: exerciseIds.map(\.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            rows = try await supabase.from("progression_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("exercise_id", values: exerciseIds.map(\.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value
        }

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

    /// Derives the user's current PRs for an exercise from the canonical
    /// `workout_sets` history rather than the `personal_records` table.
    ///
    /// Why: `personal_records` is populated only at workout completion via
    /// `detectPRs`, so if the table was ever cleared, missed an insert, or
    /// pre-dates a user's training history, it doesn't reflect reality.
    /// When that happens, inline PR detection compares this set's weight
    /// against 0 and flags every working set ≥ 1 lb as a new weight PR.
    /// Deriving from `workout_sets` makes the source of truth the actual
    /// logged sets, not the (denormalized) PR cache.
    func fetchCurrentPRs(userId: UUID, exerciseId: UUID) async throws -> [PersonalRecord] {
        struct WorkingSetRow: Decodable {
            let session_id: UUID
            let weight: Double
            let reps: Int
            let completed_at: String?
        }

        let rows: [WorkingSetRow] = try await supabase.from("workout_sets")
            .select("session_id, weight, reps, completed_at, workout_sessions!inner(user_id, status)")
            .eq("workout_sessions.user_id", value: userId.uuidString)
            .eq("workout_sessions.status", value: "completed")
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("set_type", value: "working")
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]
        func parseDate(_ str: String?) -> Date {
            guard let str else { return Date() }
            return isoFractional.date(from: str) ?? isoPlain.date(from: str) ?? Date()
        }

        var prs: [PersonalRecord] = []

        // Heaviest weight ever (with the reps achieved at that weight)
        if let best = rows.max(by: { $0.weight < $1.weight }), best.weight > 0 {
            prs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .weight, value: best.weight,
                repsAtWeight: best.reps, sessionId: best.session_id,
                achievedAt: parseDate(best.completed_at), createdAt: parseDate(best.completed_at)
            ))
        }

        // Most reps ever (any weight)
        if let best = rows.max(by: { $0.reps < $1.reps }), best.reps > 0 {
            prs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .reps, value: Double(best.reps),
                repsAtWeight: nil, sessionId: best.session_id,
                achievedAt: parseDate(best.completed_at), createdAt: parseDate(best.completed_at)
            ))
        }

        // Best estimated 1RM (Epley): weight * (1 + reps/30)
        let withE1RM = rows.map { ($0, $0.weight * (1.0 + Double($0.reps) / 30.0)) }
        if let best = withE1RM.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            prs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .estimated1rm, value: best.1,
                repsAtWeight: nil, sessionId: best.0.session_id,
                achievedAt: parseDate(best.0.completed_at), createdAt: parseDate(best.0.completed_at)
            ))
        }

        // Best per-session volume (sum of weight*reps across the session's
        // working sets for this exercise)
        var volumeBySession: [UUID: Double] = [:]
        for row in rows {
            volumeBySession[row.session_id, default: 0] += row.weight * Double(row.reps)
        }
        if let (bestSessionId, maxVolume) = volumeBySession.max(by: { $0.value < $1.value }),
           maxVolume > 0 {
            let representativeDate = rows.first(where: { $0.session_id == bestSessionId })?.completed_at
            prs.append(PersonalRecord(
                id: UUID(), userId: userId, exerciseId: exerciseId,
                recordType: .volume, value: maxVolume,
                repsAtWeight: nil, sessionId: bestSessionId,
                achievedAt: parseDate(representativeDate), createdAt: parseDate(representativeDate)
            ))
        }

        return prs
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

    /// Computes a weight increase with a floor, an RPE bonus, and a clamp:
    /// - Floor: an increase always moves the bar by at least one increment, so a
    ///   deserved bump (e.g. hitting the rep cap) can't round back to the same
    ///   weight (the old hypertrophy "sticky weight" bug).
    /// - RPE bonus: `rpeBonusIncrements` extra increments when the set was easy.
    /// - Clamp: caps the single-session jump (≥2 increments, or 5% of the anchor
    ///   for heavier lifts) so a fluke high-rep set can't prescribe a huge jump.
    private func increaseWeightTarget(
        e1rmDerived: Double,
        anchorWeight: Double,
        increment: Double,
        rpeBonusIncrements: Int
    ) -> Double {
        guard increment > 0, anchorWeight > 0 else {
            return roundToIncrement(e1rmDerived, increment)
        }
        let base = roundToIncrement(e1rmDerived, increment)
        let withBonus = base + Double(rpeBonusIncrements) * increment
        let floor = anchorWeight + increment
        let maxIncrease = max(2 * increment, roundToIncrement(anchorWeight * 0.05, increment))
        let ceiling = anchorWeight + maxIncrease
        return min(max(withBonus, floor), ceiling)
    }
}
