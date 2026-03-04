import Foundation

enum SessionStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed
    case abandoned
}

struct WorkoutSession: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var templateId: UUID?
    var workoutDayId: UUID?
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int?
    var notes: String?
    var status: SessionStatus
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case templateId = "template_id"
        case workoutDayId = "workout_day_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case notes, status
        case createdAt = "created_at"
    }
}
