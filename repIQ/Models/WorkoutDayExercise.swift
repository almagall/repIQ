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

struct WorkoutDayExercise: Codable, Identifiable, Sendable {
    let id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var trainingMode: TrainingMode
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
        trainingMode.repRange.lowerBound...effectiveRepMax
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workoutDayId = "workout_day_id"
        case exerciseId = "exercise_id"
        case trainingMode = "training_mode"
        case targetSets = "target_sets"
        case sortOrder = "sort_order"
        case restSecondsOverride = "rest_seconds_override"
        case notes
        case supersetGroup = "superset_group"
        case repCap = "rep_cap"
        case createdAt = "created_at"
        case exercise = "exercises"
    }
}
