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
        case .warmup: return "WU"
        case .working: return "W"
        case .cooldown: return "CD"
        case .drop: return "D"
        case .failure: return "F"
        }
    }

    /// Display order for grouping sets by type within an exercise.
    var sortOrder: Int {
        switch self {
        case .warmup: return 0
        case .working: return 1
        case .drop: return 2
        case .failure: return 3
        case .cooldown: return 4
        }
    }

    var icon: String {
        switch self {
        case .warmup: return "flame"
        case .working: return "dumbbell"
        case .cooldown: return "snowflake"
        case .drop: return "arrow.down.circle"
        case .failure: return "bolt.fill"
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

    /// What the engine prescribed for this set, snapshotted at log time.
    ///
    /// Nil means the set was never given a target — warm-ups and cool-downs
    /// (never pre-filled by design), drop and failure sets, extra sets beyond
    /// the prescription, and every set logged before targets were persisted.
    /// Adherence excludes those rather than counting them as misses, so
    /// `isGraded` is the gate every adherence calculation goes through.
    var targetWeight: Double?
    var targetReps: Int?
    var targetRPE: Double?

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
        case targetWeight = "target_weight"
        case targetReps = "target_reps"
        case targetRPE = "target_rpe"
    }

    var volume: Double {
        weight * Double(reps)
    }

    /// Whether this set is *eligible* for adherence — a working set carrying a
    /// stored target. Eligibility isn't the whole rule: `TargetAdherenceService`
    /// then narrows strength lifts to their top set, since ramp-up sets are
    /// prescribed to feel easy and the engine only judges the top one.
    var isGraded: Bool {
        setType == .working && targetReps != nil
    }

    /// Whether the prescription was met. Nil when the set isn't graded.
    ///
    /// Deliberately binary, and deliberately strict on load: repping out at a
    /// lighter weight is a miss, otherwise dropping the weight would score
    /// better than doing what was asked.
    var hitTarget: Bool? {
        guard isGraded, let targetReps else { return nil }
        return weight >= (targetWeight ?? 0) && reps >= targetReps
    }

    var estimated1RM: Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
