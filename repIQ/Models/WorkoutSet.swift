import Foundation

enum SetType: String, Codable, CaseIterable, Sendable {
    case warmup
    case working
    case cooldown
    case drop
    case failure

    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .working: return "Working"
        case .cooldown: return "Cool Down"
        case .drop: return "Drop Set"
        case .failure: return "To Failure"
        }
    }

    var shortName: String {
        switch self {
        case .warmup: return "W"
        case .working: return "S"
        case .cooldown: return "C"
        case .drop: return "D"
        case .failure: return "F"
        }
    }
}

struct WorkoutSet: Codable, Identifiable, Sendable {
    let id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var setNumber: Int
    var setType: SetType
    var weight: Double
    var reps: Int
    var rpe: Double?
    var isPR: Bool
    var notes: String?
    var completedAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case setType = "set_type"
        case weight, reps, rpe
        case isPR = "is_pr"
        case notes
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    var volume: Double {
        weight * Double(reps)
    }

    var estimated1RM: Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
