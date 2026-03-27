import Foundation

enum ProgressionDecision: String, Codable, Sendable {
    case increaseWeight = "increase_weight"
    case increaseReps = "increase_reps"
    case maintain
    case deload
    case deloadVolume = "deload_volume"

    var displayName: String {
        switch self {
        case .increaseWeight: return "Increase Weight"
        case .increaseReps: return "Increase Reps"
        case .maintain: return "Maintain"
        case .deload: return "Deload"
        case .deloadVolume: return "Reduce Volume"
        }
    }
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
        e1rmConfidence: Double = 1.0
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
    }

    var targetRepRangeDisplay: String {
        if targetRepsLow == targetRepsHigh {
            return "\(targetRepsLow)"
        }
        return "\(targetRepsLow)-\(targetRepsHigh)"
    }

    /// Effective RPE accounting for mesocycle progression
    var effectiveTargetRPE: Double {
        min(targetRPE + mesocycleRPEOffset, 9.5)
    }
}
