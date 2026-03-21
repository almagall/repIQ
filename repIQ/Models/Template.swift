import Foundation

struct Template: Codable, Identifiable, Sendable, Hashable {
    static func == (lhs: Template, rhs: Template) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    var userId: UUID
    var name: String
    var description: String?
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var workoutDays: [WorkoutDay]?
    var sourceProgram: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, description
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case workoutDays = "workout_days"
        case sourceProgram = "source_program"
    }
}
