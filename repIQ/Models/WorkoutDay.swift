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
}
