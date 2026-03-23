import Foundation

enum WeightUnit: String, Codable, CaseIterable {
    case lbs
    case kg

    var displayName: String {
        switch self {
        case .lbs: return "lbs"
        case .kg: return "kg"
        }
    }
}

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var email: String
    var displayName: String?
    var username: String?
    var bio: String?
    var weightUnit: WeightUnit?
    var restTimerDefault: Int?
    var hasCompletedOnboarding: Bool?
    var experienceLevel: String?
    var trainingGoal: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, username, bio
        case displayName = "display_name"
        case weightUnit = "weight_unit"
        case restTimerDefault = "rest_timer_default"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case experienceLevel = "experience_level"
        case trainingGoal = "training_goal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Safe accessor with default fallback
    var safeWeightUnit: WeightUnit { weightUnit ?? .lbs }
    var safeRestTimer: Int { restTimerDefault ?? 120 }
    var safeHasCompletedOnboarding: Bool { hasCompletedOnboarding ?? false }
}
