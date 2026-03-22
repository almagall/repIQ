import Foundation
import SwiftUI

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

enum PaceStatus {
    case ahead
    case onTrack
    case behind
    case overdue
    case noDate

    var label: String {
        switch self {
        case .ahead: return "Ahead"
        case .onTrack: return "On Track"
        case .behind: return "Behind"
        case .overdue: return "Overdue"
        case .noDate: return ""
        }
    }

    var color: Color {
        switch self {
        case .ahead: return .green
        case .onTrack: return .green
        case .behind: return .orange
        case .overdue: return .red
        case .noDate: return .clear
        }
    }
}

struct Goal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var goalType: GoalType
    var exerciseId: UUID?
    var exerciseName: String?
    var targetValue: Double
    var currentValue: Double
    var startingValue: Double
    var isEstimated1RM: Bool
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
        case startingValue = "starting_value"
        case isEstimated1RM = "is_estimated_1rm"
        case unit
        case targetDate = "target_date"
        case status
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    // MARK: - Progress

    var progress: Double {
        let range = targetValue - startingValue
        guard range > 0 else {
            // Fallback for goals with no starting value or target == start
            guard targetValue > 0 else { return 0 }
            return min(currentValue / targetValue, 1.0)
        }
        return min(max((currentValue - startingValue) / range, 0), 1.0)
    }

    var isCompleted: Bool {
        status == .completed
    }

    var delta: Double {
        max(targetValue - currentValue, 0)
    }

    // MARK: - Display

    var displayTarget: String {
        formatValue(targetValue) + " \(unit)"
    }

    var displayCurrent: String {
        formatValue(currentValue) + " \(unit)"
    }

    var goalTypeBadge: String {
        if goalType == .weight && isEstimated1RM {
            return "Est. 1RM"
        }
        return goalType.displayName
    }

    // MARK: - Time

    var daysRemaining: Int? {
        guard let targetDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: targetDate)).day
        return days
    }

    var isOverdue: Bool {
        guard let days = daysRemaining else { return false }
        return days < 0
    }

    var timeRemainingDisplay: String? {
        guard let days = daysRemaining else { return nil }
        if days < 0 {
            return "Overdue by \(abs(days)) day\(abs(days) == 1 ? "" : "s")"
        } else if days == 0 {
            return "Due today"
        } else {
            return "\(days) day\(days == 1 ? "" : "s") left"
        }
    }

    // MARK: - Pace

    var paceStatus: PaceStatus {
        guard let targetDate, let createdDate = Optional(createdAt) else { return .noDate }

        if isOverdue && !isCompleted { return .overdue }

        let calendar = Calendar.current
        let totalDays = max(calendar.dateComponents([.day], from: createdDate, to: targetDate).day ?? 1, 1)
        let elapsedDays = max(calendar.dateComponents([.day], from: createdDate, to: Date()).day ?? 0, 0)

        let expectedProgress = Double(elapsedDays) / Double(totalDays)
        let actualProgress = progress

        if actualProgress >= expectedProgress + 0.1 {
            return .ahead
        } else if actualProgress >= expectedProgress - 0.1 {
            return .onTrack
        } else {
            return .behind
        }
    }

    // MARK: - Milestones

    var milestoneReached: Int? {
        let pct = Int(progress * 100)
        if pct >= 75 && pct < 100 { return 75 }
        if pct >= 50 && pct < 75 { return 50 }
        if pct >= 25 && pct < 50 { return 25 }
        return nil
    }

    var milestoneLabel: String? {
        switch milestoneReached {
        case 75: return "Almost there"
        case 50: return "Halfway there"
        case 25: return "Great start"
        default: return nil
        }
    }

    // MARK: - Actionable Insight

    var nextStepDescription: String {
        switch goalType {
        case .weight:
            let label = isEstimated1RM ? "Est. 1RM" : "Best"
            return "\(label): \(formatValue(currentValue)) \(unit) — \(formatValue(delta)) to go"
        case .reps:
            return "Current: \(Int(currentValue)) reps — \(Int(delta)) more to go"
        case .consistency:
            return "\(Int(currentValue)) of \(Int(targetValue)) sessions this week"
        case .volume:
            return "Current: \(formatValue(currentValue)) \(unit) — \(formatValue(delta)) to go"
        case .bodyweight:
            return "Current: \(formatValue(currentValue)) \(unit)"
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
