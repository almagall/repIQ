import Foundation

/// Stateless engine that computes per-set coaching feedback and session grades.
struct SetFeedbackEngine {

    // MARK: - Per-Set Feedback

    static func computeFeedback(
        setId: UUID,
        actualWeight: Double,
        actualReps: Int,
        actualRPE: Double?,
        targetWeight: Double,
        targetReps: Int,
        targetRPE: Double,
        decision: ProgressionDecision?,
        isBodyweightOnly: Bool,
        hasTarget: Bool
    ) -> SetFeedback {

        // Baseline: no progression target exists
        guard hasTarget else {
            return SetFeedback(
                id: setId,
                outcome: .onTarget,
                headline: "Baseline recorded",
                detail: "This establishes your starting point. Personalized targets will appear next session.",
                weightDelta: 0,
                repsDelta: 0,
                rpeDelta: nil,
                isBaseline: true
            )
        }

        // --- Score weight ---
        let weightScore: SetOutcome
        let weightDelta: Double

        if isBodyweightOnly {
            weightScore = .onTarget // N/A for bodyweight
            weightDelta = 0
        } else if targetWeight > 0 {
            weightDelta = actualWeight - targetWeight
            let pct = weightDelta / targetWeight
            if pct >= 0 {
                weightScore = .exceeded
            } else if pct >= -0.025 {
                weightScore = .onTarget
            } else if pct >= -0.10 {
                weightScore = .slightlyBelow
            } else {
                weightScore = .wellBelow
            }
        } else {
            weightScore = .onTarget
            weightDelta = 0
        }

        // --- Score reps ---
        let repsDelta = actualReps - targetReps
        let repsScore: SetOutcome
        if repsDelta >= 1 {
            repsScore = .exceeded
        } else if repsDelta >= 0 {
            repsScore = .onTarget
        } else if repsDelta >= -2 {
            repsScore = .slightlyBelow
        } else {
            repsScore = .wellBelow
        }

        // --- Combine (weakest dimension wins) ---
        let combined: SetOutcome
        if isBodyweightOnly {
            combined = repsScore
        } else {
            combined = SetOutcome(rawValue: min(weightScore.rawValue, repsScore.rawValue)) ?? .wellBelow
        }

        // --- RPE modifier ---
        var outcome = combined
        let rpeDelta: Double? = actualRPE.map { $0 - targetRPE }
        if let rpe = actualRPE, rpe - targetRPE >= 2.0, outcome.rawValue > 0 {
            outcome = SetOutcome(rawValue: outcome.rawValue - 1) ?? .wellBelow
        }

        // --- Generate headline ---
        let headline = generateHeadline(
            outcome: outcome,
            weightDelta: weightDelta,
            repsDelta: repsDelta,
            isBodyweightOnly: isBodyweightOnly
        )

        // --- Generate detail ---
        let detail = generateDetail(
            outcome: outcome,
            decision: decision,
            weightDelta: weightDelta,
            repsDelta: repsDelta,
            rpeDelta: rpeDelta,
            isBodyweightOnly: isBodyweightOnly
        )

        return SetFeedback(
            id: setId,
            outcome: outcome,
            headline: headline,
            detail: detail,
            weightDelta: weightDelta,
            repsDelta: repsDelta,
            rpeDelta: rpeDelta,
            isBaseline: false
        )
    }

    // MARK: - Session Grade

    static func computeSessionGrade(feedbacks: [SetFeedback]) -> SessionPerformanceGrade {
        let graded = feedbacks.filter { !$0.isBaseline }
        guard !graded.isEmpty else {
            return SessionPerformanceGrade(
                level: .baseline,
                setsExceeded: 0, setsOnTarget: 0,
                setsSlightlyBelow: 0, setsWellBelow: 0,
                totalGradedSets: 0, percentOnOrAbove: 0
            )
        }

        let exceeded = graded.filter { $0.outcome == .exceeded }.count
        let onTarget = graded.filter { $0.outcome == .onTarget }.count
        let slightly = graded.filter { $0.outcome == .slightlyBelow }.count
        let well = graded.filter { $0.outcome == .wellBelow }.count
        let total = graded.count
        let pct = Double(exceeded + onTarget) / Double(total)

        let level: PerformanceLevel
        if pct >= 0.80 {
            level = .aboveTarget
        } else if pct >= 0.50 {
            level = .onTarget
        } else {
            level = .belowTarget
        }

        return SessionPerformanceGrade(
            level: level,
            setsExceeded: exceeded, setsOnTarget: onTarget,
            setsSlightlyBelow: slightly, setsWellBelow: well,
            totalGradedSets: total, percentOnOrAbove: pct
        )
    }

    // MARK: - Exercise Grades

    static func computeExerciseGrades(
        exercises: [ExerciseLogEntry],
        feedbacks: [UUID: SetFeedback]
    ) -> [ExercisePerformanceGrade] {
        exercises.compactMap { exercise in
            let workingSets = exercise.sets.filter { $0.setType == .working && $0.isCompleted }
            let outcomes: [SetOutcome] = workingSets.compactMap { set in
                feedbacks[set.id]?.outcome
            }
            guard !outcomes.isEmpty else { return nil }

            let avg = Double(outcomes.map(\.rawValue).reduce(0, +)) / Double(outcomes.count)
            let level: PerformanceLevel
            if avg >= 2.5 { level = .aboveTarget }
            else if avg >= 1.5 { level = .onTarget }
            else { level = .belowTarget }

            return ExercisePerformanceGrade(
                id: exercise.exerciseId,
                exerciseName: exercise.exerciseName,
                level: level,
                setOutcomes: outcomes
            )
        }
    }

    // MARK: - Headline Generation

    private static func generateHeadline(
        outcome: SetOutcome,
        weightDelta: Double,
        repsDelta: Int,
        isBodyweightOnly: Bool
    ) -> String {
        switch outcome {
        case .exceeded:
            if isBodyweightOnly || weightDelta <= 0 {
                return "+\(repsDelta) rep\(repsDelta == 1 ? "" : "s") above target"
            } else if repsDelta <= 0 {
                return "+\(formatDelta(weightDelta)) lbs over target"
            } else {
                return "+\(formatDelta(weightDelta)) lbs, +\(repsDelta) reps"
            }
        case .onTarget:
            return "Right on target"
        case .slightlyBelow:
            if !isBodyweightOnly && weightDelta < -0.025 * 100 {
                return "\(formatDelta(abs(weightDelta))) lbs under target"
            } else if repsDelta < 0 {
                return "\(abs(repsDelta)) rep\(abs(repsDelta) == 1 ? "" : "s") short"
            } else {
                return "Slightly under target"
            }
        case .wellBelow:
            if !isBodyweightOnly && weightDelta < 0 {
                return "\(formatDelta(abs(weightDelta))) lbs below target"
            } else if repsDelta < 0 {
                return "\(abs(repsDelta)) reps below target"
            } else {
                return "Below target"
            }
        }
    }

    // MARK: - Detail Generation

    private static func generateDetail(
        outcome: SetOutcome,
        decision: ProgressionDecision?,
        weightDelta: Double,
        repsDelta: Int,
        rpeDelta: Double?,
        isBodyweightOnly: Bool
    ) -> String {
        let dec = decision ?? .maintain

        switch (outcome, dec) {
        case (.exceeded, .increaseWeight):
            return "You handled the weight increase well. This confirms the progression was appropriate."
        case (.exceeded, .increaseReps):
            return "Great rep performance. You're building the volume needed to push weight up next."
        case (.exceeded, .maintain):
            return "You exceeded the maintain target. The algorithm may push weight or reps next session."
        case (.exceeded, .deload), (.exceeded, .deloadVolume):
            return "Strong performance on a deload set. Recovery is going well."

        case (.onTarget, .increaseWeight):
            return "You hit the new weight target. Solid progression."
        case (.onTarget, .increaseReps):
            return "Reps are on track. Keep this pace and a weight increase is coming."
        case (.onTarget, .maintain):
            return "Consistent execution. The algorithm will look for the right time to progress."
        case (.onTarget, .deload), (.onTarget, .deloadVolume):
            return "Deload set completed as prescribed. Recovery is part of progress."

        case (.slightlyBelow, .increaseWeight):
            return "Slightly under the new weight. This is normal when adapting to a heavier load."
        case (.slightlyBelow, .increaseReps):
            return "A couple reps short. Fatigue accumulation across sets is expected."
        case (.slightlyBelow, .maintain):
            return "Slightly under your maintain target. Could be daily fatigue — the algorithm accounts for this."
        case (.slightlyBelow, .deload), (.slightlyBelow, .deloadVolume):
            return "A bit under the deload target. No concern — deloads are about recovery, not performance."

        case (.wellBelow, .increaseWeight):
            return "The weight increase was aggressive. Focus on controlled reps — the app will adjust if needed."
        case (.wellBelow, .increaseReps):
            return "Significantly under rep target. Check if fatigue or form was a factor."
        case (.wellBelow, .maintain):
            return "Well below the maintain target. If this continues, the app may schedule a deload."
        case (.wellBelow, .deload), (.wellBelow, .deloadVolume):
            return "Under the deload target. Consider whether recovery outside the gym needs attention (sleep, nutrition)."
        }
    }

    // MARK: - Helpers

    private static func formatDelta(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
