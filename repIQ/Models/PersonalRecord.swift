import Foundation

enum RecordType: String, Codable, CaseIterable, Sendable {
    case weight
    case reps
    case volume
    case estimated1rm = "estimated_1rm"

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .volume: return "Volume"
        case .estimated1rm: return "Est. 1RM"
        }
    }
}

struct PersonalRecord: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var exerciseId: UUID
    var recordType: RecordType
    var value: Double
    var repsAtWeight: Int?
    var sessionId: UUID?
    var achievedAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case recordType = "record_type"
        case value
        case repsAtWeight = "reps_at_weight"
        case sessionId = "session_id"
        case achievedAt = "achieved_at"
        case createdAt = "created_at"
    }
}
