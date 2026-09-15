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

    // Same reason as WorkoutDay: the embedded days arrive unordered.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isActive = try c.decode(Bool.self, forKey: .isActive)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        workoutDays = try c.decodeIfPresent([WorkoutDay].self, forKey: .workoutDays)?
            .sorted { $0.sortOrder < $1.sortOrder }
        sourceProgram = try c.decodeIfPresent(String.self, forKey: .sourceProgram)
    }
}
