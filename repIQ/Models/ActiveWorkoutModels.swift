import Foundation

/// The type of personal record achieved on a set.
enum PRType: Equatable {
    case weight    // Heaviest weight ever lifted on this exercise
    case reps      // Most reps ever at this weight

    var label: String {
        switch self {
        case .weight: return "Weight PR"
        case .reps: return "Rep PR"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "trophy.fill"
        case .reps: return "flame.fill"
        }
    }
}

/// Data for the PR celebration popup shown after completing a PR set.
struct PRCelebration: Identifiable, Equatable {
    static func == (lhs: PRCelebration, rhs: PRCelebration) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    let exerciseName: String
    let prType: PRType
    let newValue: String       // e.g. "230 lbs × 10"
    let previousValue: String  // e.g. "225 lbs × 10"
    let previousDate: Date?    // when the old PR was set
    let delta: String?         // e.g. "+10 lbs" or "+2 reps"
    let percentImprovement: Double? // e.g. 4.4 for 4.4%
    let estimated1RM: Double?  // Epley formula est. 1RM (weight PRs only)
}

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
    var prType: PRType? // non-nil if this set beat a personal record

    var isPR: Bool { prType != nil }

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
        self.prType = nil
    }
}

/// Represents one exercise in the active workout with its mutable sets.
struct ExerciseLogEntry: Identifiable {
    let id: UUID // matches WorkoutDayExercise.id
    var exerciseId: UUID
    var exerciseName: String
    var muscleGroup: String
    var equipment: String
    let trainingMode: TrainingMode
    let targetSets: Int
    let restSeconds: Int
    let sortOrder: Int
    var sets: [SetEntry]
    var previousSets: [[WorkoutSet]] // last session's sets for reference
    var progressionTarget: ProgressionTarget? // progression target for this exercise
    var originalExerciseId: UUID? // non-nil if this exercise was substituted
    var isSubstituted: Bool { originalExerciseId != nil }
    var repCap: Int? // optional rep cap from template exercise config

    /// The superset group index, if this exercise is part of a superset.
    var supersetGroup: Int?

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
struct WorkoutSummaryData: Identifiable {
    var id: Int { duration.hashValue ^ totalSets.hashValue }
    let duration: Int // seconds
    let totalSets: Int
    let totalVolume: Double
    let exerciseSummaries: [ExerciseSummary]
    let newPRs: [PRSummary]
    let progressionDecisions: [ProgressionSummary]

    // Gamification
    var iqPointsEarned: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var newBadges: [Badge] = []

    // Context for sharing
    var workoutName: String = ""
    var workoutDate: Date = Date()

    init(
        duration: Int,
        totalSets: Int,
        totalVolume: Double,
        exerciseSummaries: [ExerciseSummary],
        newPRs: [PRSummary] = [],
        progressionDecisions: [ProgressionSummary] = [],
        iqPointsEarned: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        newBadges: [Badge] = []
    ) {
        self.duration = duration
        self.totalSets = totalSets
        self.totalVolume = totalVolume
        self.exerciseSummaries = exerciseSummaries
        self.newPRs = newPRs
        self.progressionDecisions = progressionDecisions
        self.iqPointsEarned = iqPointsEarned
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.newBadges = newBadges
    }

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

/// A PR achieved during a workout session.
struct PRSummary: Identifiable {
    let id = UUID()
    let exerciseName: String
    let recordType: RecordType
    let value: Double
    let previousValue: Double?
}

/// A progression decision for the next session.
struct ProgressionSummary: Identifiable {
    let id = UUID()
    let exerciseName: String
    let decision: ProgressionDecision
    let targetWeight: Double
    let targetReps: String // "10-12"
    let reasoning: String
}
