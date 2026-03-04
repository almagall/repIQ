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
    var weightUnit: WeightUnit
    var restTimerDefault: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case weightUnit = "weight_unit"
        case restTimerDefault = "rest_timer_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
