import SwiftUI

// MARK: - Set Outcome

enum SetOutcome: Int, Sendable {
    case wellBelow = 0
    case slightlyBelow = 1
    case onTarget = 2
    case exceeded = 3

    var color: Color {
        switch self {
        case .exceeded: return RQColors.success
        case .onTarget: return RQColors.accent
        case .slightlyBelow: return RQColors.warning
        case .wellBelow: return Color(hex: "FF6B35")
        }
    }

    var icon: String {
        switch self {
        case .exceeded: return "arrow.up.circle.fill"
        case .onTarget: return "checkmark.circle.fill"
        case .slightlyBelow: return "minus.circle.fill"
        case .wellBelow: return "arrow.down.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .exceeded: return "Exceeded"
        case .onTarget: return "On Target"
        case .slightlyBelow: return "Close"
        case .wellBelow: return "Below Target"
        }
    }
}

// MARK: - Set Feedback

struct SetFeedback: Identifiable, Sendable {
    let id: UUID
    let outcome: SetOutcome
    let headline: String
    let detail: String
    let weightDelta: Double
    let repsDelta: Int
    let rpeDelta: Double?
    let isBaseline: Bool
}

// MARK: - Performance Level

enum PerformanceLevel: Sendable {
    case aboveTarget
    case onTarget
    case belowTarget
    case baseline

    var color: Color {
        switch self {
        case .aboveTarget: return RQColors.success
        case .onTarget: return RQColors.accent
        case .belowTarget: return RQColors.warning
        case .baseline: return RQColors.textTertiary
        }
    }

    var icon: String {
        switch self {
        case .aboveTarget: return "star.circle.fill"
        case .onTarget: return "checkmark.circle.fill"
        case .belowTarget: return "exclamationmark.circle.fill"
        case .baseline: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .aboveTarget: return "Above Target"
        case .onTarget: return "On Target"
        case .belowTarget: return "Below Target"
        case .baseline: return "Baseline"
        }
    }
}

// MARK: - Session Performance Grade

struct SessionPerformanceGrade: Sendable {
    let level: PerformanceLevel
    let setsExceeded: Int
    let setsOnTarget: Int
    let setsSlightlyBelow: Int
    let setsWellBelow: Int
    let totalGradedSets: Int
    let percentOnOrAbove: Double

    var summary: String {
        if totalGradedSets == 0 { return "Baseline session" }
        let pct = Int(percentOnOrAbove * 100)
        return "\(pct)% of sets met or exceeded targets"
    }
}

// MARK: - Exercise Performance Grade

struct ExercisePerformanceGrade: Identifiable, Sendable {
    let id: UUID
    let exerciseName: String
    let level: PerformanceLevel
    let setOutcomes: [SetOutcome]
}
