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
