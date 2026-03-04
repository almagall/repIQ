import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case abs, forearms

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .abs: return "Abs"
        case .forearms: return "Forearms"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case smithMachine = "smith_machine"
    case other

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .bodyweight: return "Bodyweight"
        case .smithMachine: return "Smith Machine"
        case .other: return "Other"
        }
    }
}

struct Exercise: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var userId: UUID?
    var name: String
    var muscleGroup: String
    var equipment: String
    var isCompound: Bool
    var defaultRestSeconds: Int
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case muscleGroup = "muscle_group"
        case equipment
        case isCompound = "is_compound"
        case defaultRestSeconds = "default_rest_seconds"
        case notes
        case createdAt = "created_at"
    }

    var isBuiltIn: Bool { userId == nil }
}
