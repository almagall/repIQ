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

struct ProgramDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: ProgramCategory
    let difficulty: ProgramDifficulty
    let daysPerWeek: Int
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
    let setScheme: SetScheme
    let targetSets: Int
    let repCap: Int?
    let restSecondsOverride: Int?
    let notes: String?

    init(
        exerciseName: String,
        trainingMode: TrainingMode,
        setScheme: SetScheme = .ramped,
        targetSets: Int,
        repCap: Int? = nil,
        restSecondsOverride: Int? = nil,
        notes: String? = nil
    ) {
        self.id = "\(exerciseName)-\(trainingMode.rawValue)"
        self.exerciseName = exerciseName
        self.trainingMode = trainingMode
        self.setScheme = setScheme
        self.targetSets = targetSets
        self.repCap = repCap
        self.restSecondsOverride = restSecondsOverride
        self.notes = notes
    }
}
