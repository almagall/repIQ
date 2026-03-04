import Foundation

/// Represents a single set row in the active workout UI.
/// Mutable local state — once completed, maps to a WorkoutSet in Supabase.
struct SetEntry: Identifiable {
    let id: UUID
    var setNumber: Int
    var setType: SetType
    var weight: Double
    var reps: Int
    var rpe: Double?
    var isCompleted: Bool
    var savedSetId: UUID? // non-nil once persisted to workout_sets
    var isSaving: Bool // loading state on checkmark tap

    init(
        setNumber: Int,
        setType: SetType = .working,
        weight: Double = 0,
        reps: Int = 0,
        rpe: Double? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.setType = setType
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = false
        self.savedSetId = nil
        self.isSaving = false
    }
}

/// Represents one exercise in the active workout with its mutable sets.
struct ExerciseLogEntry: Identifiable {
    let id: UUID // matches WorkoutDayExercise.id
    let exerciseId: UUID
    let exerciseName: String
    let muscleGroup: String
    let equipment: String
    let trainingMode: TrainingMode
    let targetSets: Int
    let restSeconds: Int
    let sortOrder: Int
    var sets: [SetEntry]
    var previousSets: [[WorkoutSet]] // last session's sets for reference
    var isExpanded: Bool // whether previous sets are shown

    var completedSetCount: Int {
        sets.filter(\.isCompleted).count
    }

    var isAllSetsCompleted: Bool {
        completedSetCount >= targetSets
    }

    var totalVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

/// Post-workout summary data.
struct WorkoutSummaryData {
    let duration: Int // seconds
    let totalSets: Int
    let totalVolume: Double
    let exerciseSummaries: [ExerciseSummary]

    struct ExerciseSummary: Identifiable {
        let id: UUID // exerciseId
        let name: String
        let muscleGroup: String
        let trainingMode: TrainingMode
        let setsCompleted: Int
        let totalVolume: Double
        let topWeight: Double
        let topReps: Int
    }
}
