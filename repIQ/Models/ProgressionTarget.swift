import Foundation

enum ProgressionDecision: String, Codable, Sendable {
    case increaseWeight = "increase_weight"
    case increaseReps = "increase_reps"
    case maintain
    case deload
    case deloadVolume = "deload_volume"
    /// A program rule moved to its next scheduled step. Neutral: it is neither
    /// progress nor a hold, so progression-rate reads skip it and use the last
    /// real decision (a 5/3/1 lifter's TM bump or reset at the cycle boundary).
    case wave

    var displayName: String {
        switch self {
        case .increaseWeight: return "Increase Weight"
        case .increaseReps: return "Increase Reps"
        case .maintain: return "Maintain"
        case .deload: return "Deload"
        case .deloadVolume: return "Reduce Volume"
        case .wave: return "Next Wave"
        }
    }

    /// Decisions that say something about strength direction. `.wave` does not.
    var isVerdict: Bool { self != .wave }
}

struct ProgressionTarget: Sendable {
    let exerciseId: UUID
    let trainingMode: TrainingMode
    let targetWeight: Double
    let targetRepsLow: Int
    let targetRepsHigh: Int
    let targetRPE: Double
    let decision: ProgressionDecision
    let reasoning: String

    let previousWeight: Double?
    let previousReps: Int?
    let previousRPE: Double?
    let estimatedOneRM: Double?

    // Mesocycle-aware RPE adjustment (0.0 = no adjustment, positive = train harder)
    let mesocycleRPEOffset: Double

    // Whether RPE fatigue signal contributed to the decision
    let rpeFatigueDetected: Bool

    // e1RM confidence factor (1.0 = high confidence at low reps, lower at high reps)
    let e1rmConfidence: Double

    /// For program rules with a schedule: the step the *next* session should
    /// run (5/3/1: wave index 0-3). Persisted in `progression_log.mesocycle_week`.
    /// Nil for the autoregulated engine.
    let programWeek: Int?

    init(
        exerciseId: UUID,
        trainingMode: TrainingMode,
        targetWeight: Double,
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double,
        decision: ProgressionDecision,
        reasoning: String,
        previousWeight: Double? = nil,
        previousReps: Int? = nil,
        previousRPE: Double? = nil,
        estimatedOneRM: Double? = nil,
        mesocycleRPEOffset: Double = 0,
        rpeFatigueDetected: Bool = false,
        e1rmConfidence: Double = 1.0,
        programWeek: Int? = nil
    ) {
        self.exerciseId = exerciseId
        self.trainingMode = trainingMode
        self.targetWeight = targetWeight
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
        self.decision = decision
        self.reasoning = reasoning
        self.previousWeight = previousWeight
        self.previousReps = previousReps
        self.previousRPE = previousRPE
        self.estimatedOneRM = estimatedOneRM
        self.mesocycleRPEOffset = mesocycleRPEOffset
        self.rpeFatigueDetected = rpeFatigueDetected
        self.e1rmConfidence = e1rmConfidence
        self.programWeek = programWeek
    }

    var targetRepRangeDisplay: String {
        // Defensive ordering: if a saved row has low > high (legacy data from
        // before the rep-cap clamping bug was fixed), collapse to a single value
        // rather than rendering as "13-12".
        let lo = min(targetRepsLow, targetRepsHigh)
        let hi = max(targetRepsLow, targetRepsHigh)
        if lo == hi {
            return "\(lo)"
        }
        return "\(lo)-\(hi)"
    }

    /// Effective RPE accounting for mesocycle progression
    var effectiveTargetRPE: Double {
        min(targetRPE + mesocycleRPEOffset, 9.5)
    }
}
