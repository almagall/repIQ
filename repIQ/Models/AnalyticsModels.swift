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

// MARK: - Push/Pull Balance

struct PushPullBalance {
    let pushVolume: Double
    let pullVolume: Double
    let pushSets: Int
    let pullSets: Int

    /// Push:Pull ratio (e.g., 1.3 means 30% more push than pull).
    var ratio: Double {
        guard pullVolume > 0 else { return pushVolume > 0 ? .infinity : 1.0 }
        return pushVolume / pullVolume
    }

    /// Formatted ratio string like "1.3 : 1".
    var ratioString: String {
        guard pullVolume > 0 else { return pushVolume > 0 ? "All Push" : "N/A" }
        return String(format: "%.1f : 1", ratio)
    }

    var status: PushPullStatus {
        PushPullStatus.from(ratio: ratio)
    }

    /// Push muscle groups: chest, shoulders, triceps.
    static let pushGroups: Set<String> = ["chest", "shoulders", "triceps"]
    /// Pull muscle groups: back, biceps.
    static let pullGroups: Set<String> = ["back", "biceps"]
}

enum PushPullStatus: String, Sendable {
    case balanced       // 0.8 – 1.3
    case pushDominant   // > 1.3
    case pullDominant   // < 0.8

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .pushDominant: return "Push Heavy"
        case .pullDominant: return "Pull Heavy"
        }
    }

    var color: Color {
        switch self {
        case .balanced: return RQColors.success
        case .pushDominant: return RQColors.warning
        case .pullDominant: return RQColors.info
        }
    }

    var icon: String {
        switch self {
        case .balanced: return "checkmark.circle"
        case .pushDominant: return "arrow.right.circle"
        case .pullDominant: return "arrow.left.circle"
        }
    }

    static func from(ratio: Double) -> PushPullStatus {
        if ratio > 1.3 { return .pushDominant }
        if ratio < 0.8 { return .pullDominant }
        return .balanced
    }
}

// MARK: - Volume Landmarks

struct VolumeLandmarkData: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let currentWeeklySets: Int
    let mev: Int // Minimum Effective Volume
    let mav: ClosedRange<Int> // Maximum Adaptive Volume range
    let mrv: Int // Maximum Recoverable Volume

    var status: VolumeLandmarkStatus {
        if currentWeeklySets < mev { return .belowMEV }
        if currentWeeklySets <= mav.upperBound { return .withinMAV }
        if currentWeeklySets <= mrv { return .approachingMRV }
        return .aboveMRV
    }

    /// Progress within the MEV → MRV range (0.0 – 1.0+).
    var progressInRange: Double {
        guard mrv > mev else { return 0 }
        return Double(currentWeeklySets - mev) / Double(mrv - mev)
    }

    var color: Color {
        RQColors.muscleGroupColors[muscleGroup] ?? RQColors.textTertiary
    }

    /// Actionable prescription based on the current status vs landmarks.
    /// Returns nil when the muscle is in the sweet spot (no action needed).
    var prescription: String? {
        switch status {
        case .belowMEV:
            let deficit = max(1, mev - currentWeeklySets)
            return "Add \(deficit)-\(deficit + 2) sets/wk"
        case .withinMAV:
            return nil
        case .approachingMRV:
            return "Monitor fatigue"
        case .aboveMRV:
            let excess = max(1, currentWeeklySets - mrv)
            return "Reduce \(excess)-\(excess + 2) sets/wk"
        }
    }
}

enum VolumeLandmarkStatus: String, Sendable {
    case belowMEV       // Under-training
    case withinMAV      // Sweet spot
    case approachingMRV // High but recoverable
    case aboveMRV       // Over-training risk

    var displayName: String {
        switch self {
        case .belowMEV: return "Below MEV"
        case .withinMAV: return "Sweet Spot"
        case .approachingMRV: return "High Volume"
        case .aboveMRV: return "Over MRV"
        }
    }

    var color: Color {
        switch self {
        case .belowMEV: return RQColors.warning
        case .withinMAV: return RQColors.success
        case .approachingMRV: return RQColors.info
        case .aboveMRV: return RQColors.error
        }
    }

    var icon: String {
        switch self {
        case .belowMEV: return "arrow.down.circle"
        case .withinMAV: return "checkmark.circle"
        case .approachingMRV: return "exclamationmark.circle"
        case .aboveMRV: return "xmark.circle"
        }
    }
}

// MARK: - Consistency Score

struct ConsistencyScore {
    let overall: Int // 0–100
    let frequencyScore: Double // 0–1
    let volumeStabilityScore: Double // 0–1
    let streakScore: Double // 0–1
    let recencyScore: Double // 0–1

    var grade: ConsistencyGrade {
        ConsistencyGrade.from(score: overall)
    }
}

enum ConsistencyGrade: String, Sendable {
    case elite      // 90–100
    case strong     // 75–89
    case good       // 60–74
    case developing // 40–59
    case beginning  // 0–39

    var displayName: String {
        switch self {
        case .elite: return "Elite"
        case .strong: return "Strong"
        case .good: return "Good"
        case .developing: return "Developing"
        case .beginning: return "Beginning"
        }
    }

    var color: Color {
        switch self {
        case .elite: return RQColors.accent
        case .strong: return RQColors.success
        case .good: return RQColors.chartPositive
        case .developing: return RQColors.warning
        case .beginning: return RQColors.textTertiary
        }
    }

    static func from(score: Int) -> ConsistencyGrade {
        if score >= 90 { return .elite }
        if score >= 75 { return .strong }
        if score >= 60 { return .good }
        if score >= 40 { return .developing }
        return .beginning
    }
}

// MARK: - Strength Prediction

struct StrengthPrediction {
    let currentE1RM: Double
    let projectedE1RM: Double // 4 weeks out
    let weeklyGainRate: Double // lbs per week (from linear regression slope)
    let confidence: Double // R² value (0–1)

    /// Projected change in lbs over 4 weeks.
    var projectedGain: Double { projectedE1RM - currentE1RM }

    /// Projected change as a percentage.
    var projectedGainPercent: Double {
        guard currentE1RM > 0 else { return 0 }
        return (projectedGain / currentE1RM) * 100
    }

    /// True if we have enough data and a reasonable fit.
    var isReliable: Bool { confidence >= 0.3 }
}

// MARK: - Top Lift Trajectory (hero card on Progress tab)

struct TopLiftTrajectory: Identifiable, Sendable {
    let exerciseId: UUID
    let exerciseName: String
    let muscleGroup: String
    let sessionCount: Int
    let currentE1RM: Double
    let fourWeekDelta: Double
    let fourWeekDeltaPercent: Double
    let velocityStatus: VelocityStatus
    let weeklyPercent: Double
    let narrative: String
    let sparkline: [Double] // recent e1RM values for the mini chart

    var id: UUID { exerciseId }

    /// Builds a one-sentence coaching narrative based on velocity and delta.
    static func buildNarrative(status: VelocityStatus, weeklyPercent: Double, deltaPercent: Double, sessionCount: Int) -> String {
        if sessionCount < 3 {
            return "Building baseline — keep logging"
        }
        switch status {
        case .accelerating:
            return String(format: "Trending up +%.1f%%/wk — strong gains", weeklyPercent)
        case .progressing:
            return String(format: "Progressing +%.1f%%/wk — on track", weeklyPercent)
        case .maintaining:
            if abs(deltaPercent) < 1.0 {
                return "Maintaining — consider a progression push"
            }
            return "Holding steady"
        case .stalling:
            return "Plateau — try variety or deload"
        case .regressing:
            return String(format: "Regressing %.1f%%/wk — check recovery", weeklyPercent)
        }
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
