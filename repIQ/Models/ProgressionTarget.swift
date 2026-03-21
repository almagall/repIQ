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

    var targetRepRangeDisplay: String {
        if targetRepsLow == targetRepsHigh {
            return "\(targetRepsLow)"
        }
        return "\(targetRepsLow)-\(targetRepsHigh)"
    }
}
