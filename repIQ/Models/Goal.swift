import Foundation

enum GoalType: String, Codable, CaseIterable {
    case weight       // Hit a target weight on an exercise
    case reps         // Hit a target reps at a given weight
    case volume       // Total weekly volume target
    case consistency  // Train X times per week for Y weeks
    case bodyweight   // Bodyweight target (future)

    var displayName: String {
        switch self {
        case .weight: return "Lift Weight"
        case .reps: return "Hit Reps"
        case .volume: return "Weekly Volume"
        case .consistency: return "Consistency"
        case .bodyweight: return "Body Weight"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .reps: return "repeat"
        case .volume: return "chart.bar.fill"
        case .consistency: return "calendar"
        case .bodyweight: return "figure.stand"
        }
    }
}

enum GoalStatus: String, Codable {
    case active
    case completed
    case abandoned
}

struct Goal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var goalType: GoalType
    var exerciseId: UUID?
    var exerciseName: String?
    var targetValue: Double
    var currentValue: Double
    var unit: String
    var targetDate: Date?
    var status: GoalStatus
    var createdAt: Date
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goalType = "goal_type"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case targetValue = "target_value"
        case currentValue = "current_value"
        case unit
        case targetDate = "target_date"
        case status
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }

    var isCompleted: Bool {
        status == .completed
    }

    var displayTarget: String {
        let formatted = targetValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", targetValue)
            : String(format: "%.1f", targetValue)
        return "\(formatted) \(unit)"
    }

    var displayCurrent: String {
        let formatted = currentValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", currentValue)
            : String(format: "%.1f", currentValue)
        return "\(formatted) \(unit)"
    }
}
