import Foundation
import SwiftUI

// MARK: - Weekly Volume

struct WeeklyVolumeSummary: Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let totalVolume: Double
    let sessionCount: Int
}

// MARK: - Muscle Group Distribution

struct MuscleGroupVolume: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let volume: Double
    let percentage: Double
    let setCount: Int

    var color: Color {
        RQColors.muscleGroupColors[muscleGroup] ?? RQColors.textTertiary
    }
}

// MARK: - Per-Exercise Snapshot

struct ExerciseSessionSnapshot: Identifiable {
    let id: UUID
    let date: Date
    let bestWeight: Double
    let bestReps: Int
    let totalVolume: Double
    let avgRPE: Double?
    let estimated1RM: Double
    let setCount: Int
}

// MARK: - Streak

struct StreakData {
    let currentStreak: Int
    let bestStreak: Int
    let lastWorkoutDate: Date?
}

// MARK: - Milestones

enum MilestoneCategory: String, CaseIterable, Sendable {
    case sessions
    case volume
    case streaks
    case prs
    case exercises

    var displayName: String {
        switch self {
        case .sessions: return "Sessions"
        case .volume: return "Volume"
        case .streaks: return "Streaks"
        case .prs: return "Personal Records"
        case .exercises: return "Exercises"
        }
    }
}

struct MilestoneDefinition: Identifiable {
    let id: String
    let category: MilestoneCategory
    let title: String
    let description: String
    let icon: String
    let threshold: Double
    var isAchieved: Bool
    var progress: Double // 0.0 - 1.0
}

// MARK: - Insight Card

struct InsightCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let accentColor: Color
    let priority: Int
}

// MARK: - Milestone Progress Data

struct MilestoneProgressData {
    let totalSessions: Int
    let totalVolume: Double
    let totalPRs: Int
    let bestStreak: Int
    let currentStreak: Int
    let uniqueExercises: Int
    let uniqueMuscleGroups: Int
}

// MARK: - Progress Velocity

enum VelocityStatus: String, Sendable {
    case accelerating   // >2% per week
    case progressing    // 0.5–2% per week
    case maintaining    // -0.5 to 0.5%
    case stalling       // -2 to -0.5%
    case regressing     // < -2%

    var displayName: String {
        switch self {
        case .accelerating: return "Accelerating"
        case .progressing: return "Progressing"
        case .maintaining: return "Maintaining"
        case .stalling: return "Stalling"
        case .regressing: return "Regressing"
        }
    }

    var icon: String {
        switch self {
        case .accelerating: return "arrow.up.right.circle.fill"
        case .progressing: return "arrow.up.right"
        case .maintaining: return "arrow.right"
        case .stalling: return "arrow.down.right"
        case .regressing: return "arrow.down.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .accelerating: return RQColors.success
        case .progressing: return RQColors.chartPositive
        case .maintaining: return RQColors.textSecondary
        case .stalling: return RQColors.warning
        case .regressing: return RQColors.error
        }
    }

    /// Classify from weekly % change in E1RM.
    static func from(weeklyPercent: Double) -> VelocityStatus {
        if weeklyPercent > 2.0 { return .accelerating }
        if weeklyPercent > 0.5 { return .progressing }
        if weeklyPercent > -0.5 { return .maintaining }
        if weeklyPercent > -2.0 { return .stalling }
        return .regressing
    }
}

// MARK: - Plateau Detection

enum PlateauCause: String, Sendable {
    case insufficientVolume
    case highFatigue
    case lowFrequency
    case needsVariety

    var displayName: String {
        switch self {
        case .insufficientVolume: return "Low Volume"
        case .highFatigue: return "High Fatigue"
        case .lowFrequency: return "Low Frequency"
        case .needsVariety: return "Needs Variety"
        }
    }

    var recommendation: String {
        switch self {
        case .insufficientVolume: return "Try adding 1–2 more working sets per session."
        case .highFatigue: return "Consider a deload week — your RPE has been consistently high."
        case .lowFrequency: return "Aim to train this movement at least 2x per week."
        case .needsVariety: return "Try a variation or accessory to target weak points."
        }
    }

    var icon: String {
        switch self {
        case .insufficientVolume: return "chart.bar.xaxis"
        case .highFatigue: return "bolt.trianglebadge.exclamationmark"
        case .lowFrequency: return "calendar.badge.exclamationmark"
        case .needsVariety: return "arrow.triangle.branch"
        }
    }
}

struct PlateauAnalysis {
    let sessionsStalled: Int
    let currentE1RM: Double
    let causes: [PlateauCause]
}

// MARK: - Effective Reps

struct EffectiveRepsSummary: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let effectiveReps: Int
    let totalReps: Int
    let totalSets: Int

    var effectiveRatio: Double {
        guard totalReps > 0 else { return 0 }
        return Double(effectiveReps) / Double(totalReps)
    }

    var color: Color {
        RQColors.muscleGroupColors[muscleGroup] ?? RQColors.textTertiary
    }
}

// MARK: - Compound Synergist Map

enum CompoundSynergistMap {
    /// Maps primary muscle group → synergist muscle groups for compound exercises.
    static let synergists: [String: [String]] = [
        "chest": ["triceps", "shoulders"],
        "back": ["biceps"],
        "shoulders": ["triceps"],
        "quads": ["glutes", "hamstrings"],
        "hamstrings": ["glutes"],
        "glutes": ["hamstrings", "quads"],
        "biceps": [],
        "triceps": [],
        "calves": [],
        "abs": [],
        "forearms": [],
    ]

    /// Returns synergist groups for a given primary group when the exercise is compound.
    static func synergistGroups(primary: String, isCompound: Bool) -> [String] {
        guard isCompound else { return [] }
        return synergists[primary] ?? []
    }

    /// Synergist volume receives 0.5x credit (Pelland et al. 2024 heuristic).
    static let synergistMultiplier: Double = 0.5

    /// Calculates effective (stimulating) reps for a single set.
    /// Based on Beardsley framework: last ~5 reps before failure produce maximum stimulus.
    /// RPE → RIR: RIR = 10 - RPE. Effective reps = min(reps, max(0, 5 - RIR)).
    static func effectiveReps(reps: Int, rpe: Double?) -> Int {
        let assumedRPE = rpe ?? 8.0
        let rir = max(0.0, 10.0 - assumedRPE)
        return min(reps, max(0, Int(5.0 - rir)))
    }
}
