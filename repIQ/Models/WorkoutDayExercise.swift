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

/// Who decides an exercise's numbers each session. The engine is the default;
/// a program rule is added only when a program's identity *is* its rule and the
/// engine can't express it. A non-autoregulated rule owns the set layout, so
/// `setScheme`, `targetSets` and `repCap` are ignored under it.
enum ProgressionRule: String, Codable, CaseIterable, Sendable {
    /// `ProgressionService.calculateTarget` — reactive double progression.
    case autoregulated
    /// Wendler's 5/3/1: three sets at percentages of a training max, a
    /// four-session wave cycle, and the TM moves only at the cycle boundary.
    case wave531 = "wave_531"

    var displayName: String {
        switch self {
        case .autoregulated: return "Autoregulated"
        case .wave531: return "5/3/1"
        }
    }
}

struct WorkoutDayExercise: Codable, Identifiable, Sendable {
    let id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var trainingMode: TrainingMode
    var setScheme: SetScheme
    var progressionRule: ProgressionRule
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
        case progressionRule = "progression_rule"
        case targetSets = "target_sets"
        case sortOrder = "sort_order"
        case restSecondsOverride = "rest_seconds_override"
        case notes
        case supersetGroup = "superset_group"
        case repCap = "rep_cap"
        case createdAt = "created_at"
        case exercise = "exercises"
    }

    // set_scheme (20260910) and progression_rule (20260914) are decoded
    // leniently so a client that ships ahead of a migration still loads
    // templates instead of failing every fetch.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutDayId = try c.decode(UUID.self, forKey: .workoutDayId)
        exerciseId = try c.decode(UUID.self, forKey: .exerciseId)
        trainingMode = try c.decode(TrainingMode.self, forKey: .trainingMode)
        setScheme = try c.decodeIfPresent(SetScheme.self, forKey: .setScheme) ?? .ramped
        progressionRule = try c.decodeIfPresent(ProgressionRule.self, forKey: .progressionRule) ?? .autoregulated
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
