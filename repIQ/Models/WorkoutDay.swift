import Foundation

struct WorkoutDay: Codable, Identifiable, Sendable {
    let id: UUID
    var templateId: UUID
    var name: String
    var description: String?
    var sortOrder: Int
    var createdAt: Date
    var exercises: [WorkoutDayExercise]?

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name, description
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case exercises = "workout_day_exercises"
    }

    // A nested PostgREST embed comes back in no particular order, so the
    // exercises are sorted here rather than at every consumer.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        templateId = try c.decode(UUID.self, forKey: .templateId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        exercises = try c.decodeIfPresent([WorkoutDayExercise].self, forKey: .exercises)?
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
