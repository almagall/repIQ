import Foundation

enum TrainingMode: String, Codable, CaseIterable, Sendable {
    case hypertrophy
    case strength

    var displayName: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        }
    }

    var repRange: ClosedRange<Int> {
        switch self {
        case .hypertrophy: return 10...15
        case .strength: return 3...5
        }
    }

    var targetRPE: Double {
        switch self {
        case .hypertrophy: return 8.0
        case .strength: return 8.0
        }
    }
}

/// How working-set loads are laid out across a strength exercise. Hypertrophy
/// is always straight sets and ignores this.
enum SetScheme: String, Codable, CaseIterable, Sendable {
    /// Weight ascends set to set; only the top set is heavy and only the top set is judged.
    case ramped
    /// Every set at the prescribed weight; the weakest set gates progression.
    case straight

    var displayName: String {
        switch self {
        case .ramped: return "Ramped"
        case .straight: return "Straight"
        }
    }
}

struct WorkoutDayExercise: Codable, Identifiable, Sendable {
    let id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var trainingMode: TrainingMode
    var setScheme: SetScheme
    var targetSets: Int
    var sortOrder: Int
    var restSecondsOverride: Int?
    var notes: String?
    var supersetGroup: Int?
    var repCap: Int?
    var createdAt: Date
    var exercise: Exercise?

    /// The effective upper bound for reps, respecting the optional rep cap.
    var effectiveRepMax: Int {
        min(repCap ?? trainingMode.repRange.upperBound, trainingMode.repRange.upperBound)
    }

    /// The effective rep range, narrowed by the rep cap if set.
    var effectiveRepRange: ClosedRange<Int> {
        let lower = trainingMode.repRange.lowerBound
        let upper = max(effectiveRepMax, lower)
        return lower...upper
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workoutDayId = "workout_day_id"
        case exerciseId = "exercise_id"
        case trainingMode = "training_mode"
        case setScheme = "set_scheme"
        case targetSets = "target_sets"
        case sortOrder = "sort_order"
        case restSecondsOverride = "rest_seconds_override"
        case notes
        case supersetGroup = "superset_group"
        case repCap = "rep_cap"
        case createdAt = "created_at"
        case exercise = "exercises"
    }

    // set_scheme arrived in 20260910_set_scheme.sql. Decoding it leniently means
    // a client that ships ahead of the migration still loads templates instead
    // of failing every fetch.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutDayId = try c.decode(UUID.self, forKey: .workoutDayId)
        exerciseId = try c.decode(UUID.self, forKey: .exerciseId)
        trainingMode = try c.decode(TrainingMode.self, forKey: .trainingMode)
        setScheme = try c.decodeIfPresent(SetScheme.self, forKey: .setScheme) ?? .ramped
        targetSets = try c.decode(Int.self, forKey: .targetSets)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        restSecondsOverride = try c.decodeIfPresent(Int.self, forKey: .restSecondsOverride)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        supersetGroup = try c.decodeIfPresent(Int.self, forKey: .supersetGroup)
        repCap = try c.decodeIfPresent(Int.self, forKey: .repCap)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        exercise = try c.decodeIfPresent(Exercise.self, forKey: .exercise)
    }
}
