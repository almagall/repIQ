import Foundation

enum ProgramCategory: String, CaseIterable {
    case hypertrophy
    case strength
    case hybrid

    var displayName: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        case .hybrid: return "Hybrid"
        }
    }
}

enum ProgramDifficulty: String {
    case beginner
    case intermediate
    case advanced

    var displayName: String { rawValue.capitalized }
}

enum ProgramProgressionType: String {
    case standard
    case percentageBased
    case linearProgression
}

struct ProgramDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: ProgramCategory
    let difficulty: ProgramDifficulty
    let daysPerWeek: Int
    let progressionType: ProgramProgressionType
    let tags: [String]
    let days: [ProgramDayDefinition]
}

struct ProgramDayDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let exercises: [ProgramExerciseDefinition]
}

struct ProgramExerciseDefinition: Identifiable {
    let id: String
    let exerciseName: String
    let trainingMode: TrainingMode
    let targetSets: Int
    let restSecondsOverride: Int?
    let notes: String?

    init(
        exerciseName: String,
        trainingMode: TrainingMode,
        targetSets: Int,
        restSecondsOverride: Int? = nil,
        notes: String? = nil
    ) {
        self.id = "\(exerciseName)-\(trainingMode.rawValue)"
        self.exerciseName = exerciseName
        self.trainingMode = trainingMode
        self.targetSets = targetSets
        self.restSecondsOverride = restSecondsOverride
        self.notes = notes
    }
}
