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

/// Training distribution for one muscle group over a window.
///
/// Balance is expressed in **sets**, not volume. Absolute load differs between
/// muscle groups for physiological reasons — four sets of squats move several
/// times the poundage of four sets of curls at identical training stimulus — so
/// a volume share makes legs and back look dominant and arms look neglected for
/// every user regardless of how they programmed the week. Sets per week is the
/// standard the hypertrophy literature uses. `volume` is retained because the
/// Rep Sheet still reports tonnage.
struct MuscleGroupVolume: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let displayName: String
    let volume: Double
    /// Share of total *sets* across all groups (0–100).
    let percentage: Double
    /// Fractional because synergists earn half credit on compound lifts.
    let setCount: Double
    /// `setCount` normalised to a weekly rate, so the number stays comparable
    /// as the user changes the time window.
    let weeklySets: Double

    var color: Color {
        RQColors.muscleGroupColors[muscleGroup] ?? RQColors.textTertiary
    }

    /// Weekly sets rounded for display; halves are preserved ("13.5") because
    /// synergist credit routinely lands on one.
    var weeklySetsDisplay: String {
        let rounded = (weeklySets * 2).rounded() / 2
        return rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
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

    /// Collapses the five velocity states into the three-colour language used
    /// across the Progress tab. Five distinct colours in a summary view reads
    /// as noise; the full granularity stays on the exercise drill-in.
    var trend: StrengthTrend {
        switch self {
        case .accelerating, .progressing: return .rising
        case .maintaining, .stalling: return .holding
        case .regressing: return .slipping
        }
    }
}

// MARK: - Progression Verdict (Progress tab hero)

/// The three-colour vocabulary shared by the hero, the trajectory rows and the
/// insight labels. Learned once, reused everywhere.
enum StrengthTrend: String, Sendable {
    case rising
    case holding
    case slipping

    var color: Color {
        switch self {
        case .rising: return RQColors.success
        case .holding: return RQColors.warning
        case .slipping: return RQColors.error
        }
    }

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .holding: return "arrow.right"
        case .slipping: return "arrow.down.right"
        }
    }
}

/// Aggregate answer to "am I progressing?", derived from the progression
/// engine's own decisions rather than from e1RM. Works for every exercise the
/// app can log — bodyweight, machine and barbell alike — because every
/// exercise gets a decision regardless of whether an e1RM is meaningful.
struct ProgressionVerdict: Sendable {
    /// Exercises whose latest decision was to add weight.
    let addedWeight: Int
    /// Exercises whose latest decision was to add reps.
    let addedReps: Int
    /// Exercises holding at their current prescription.
    let holding: Int
    /// Exercises the engine pulled back (deload or volume deload).
    let deloading: Int
    /// Regularly-trained exercises that don't yet have enough history to judge.
    /// Non-zero only in the baseline state.
    let buildingBaseline: Int

    /// Exercises moving up: added weight or added reps.
    var movingUp: Int { addedWeight + addedReps }

    /// Regularly-trained exercises with a usable decision.
    var total: Int { addedWeight + addedReps + holding + deloading }

    /// True when there isn't enough history to render a verdict yet.
    var isBaseline: Bool { total == 0 }

    /// Share of tracked exercises moving up (0–1). Zero when nothing qualifies.
    var progressingShare: Double {
        guard total > 0 else { return 0 }
        return Double(movingUp) / Double(total)
    }

    var trend: StrengthTrend {
        // Any deloading at all with little forward movement means the engine is
        // actively pulling the user back — that's a slipping month regardless
        // of how the remaining lifts look.
        if deloading > 0 && progressingShare < 0.34 { return .slipping }
        if progressingShare >= 0.6 { return .rising }
        if progressingShare >= 0.34 { return .holding }
        return .slipping
    }

    var headline: String {
        switch trend {
        case .rising: return "PROGRESSING"
        case .holding: return "HOLDING"
        case .slipping: return "SLIPPING"
        }
    }

    /// Placeholder used before the first fetch resolves, so the hero can render
    /// its baseline state rather than being conditionally absent.
    static let empty = ProgressionVerdict(
        addedWeight: 0, addedReps: 0, holding: 0,
        deloading: 0, buildingBaseline: 0
    )

    /// Muted supporting line, e.g. "7 added weight · 2 added reps · 3 holding".
    /// Omits zero-valued components so sparse months don't read as failures.
    var breakdown: String {
        var parts: [String] = []
        if addedWeight > 0 { parts.append("\(addedWeight) added weight") }
        if addedReps > 0 { parts.append("\(addedReps) added reps") }
        if holding > 0 { parts.append("\(holding) holding") }
        if deloading > 0 { parts.append("\(deloading) deloading") }
        return parts.joined(separator: "  ·  ")
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

// MARK: - Time Window

/// User-selected window that scopes the windowable Progress-tab analytics
/// (volume trend, muscle distribution, effective reps, PR markers). Sections
/// whose meaning is independent of the window — current month stats, last
/// workout, weekly volume zones — ignore this.
enum TimeWindow: String, CaseIterable, Sendable {
    case fourWeeks
    case twelveWeeks
    case sixMonths
    case oneYear
    case all

    var label: String {
        switch self {
        case .fourWeeks: return "4W"
        case .twelveWeeks: return "12W"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        case .all: return "ALL"
        }
    }

    /// Approximate days the window spans; "all" capped at two years.
    var days: Int {
        switch self {
        case .fourWeeks: return 28
        case .twelveWeeks: return 84
        case .sixMonths: return 180
        case .oneYear: return 365
        case .all: return 730
        }
    }

    /// Number of weeks for trend-style fetches.
    var weeks: Int {
        switch self {
        case .fourWeeks: return 4
        case .twelveWeeks: return 12
        case .sixMonths: return 26
        case .oneYear: return 52
        case .all: return 104
        }
    }
}

// MARK: - Past Me Snapshot

/// Compares the user's current top lift to where they were ~3 months ago.
/// Powers the "vs past you" card under the Last Workout recap.
struct PastMeSnapshot: Sendable {
    let exerciseId: UUID
    let exerciseName: String
    /// Most recent best e1RM for this exercise.
    let currentE1RM: Double
    /// Best e1RM the user achieved in the snapshot closest to `comparisonDate`.
    let pastE1RM: Double
    /// The actual date of the past snapshot (may not be exactly 3 months).
    let pastDate: Date
    /// Best single-set weight × reps at the past snapshot, for the "you used
    /// to lift X for Y reps" narrative.
    let pastWeight: Double
    let pastReps: Int

    /// Pounds gained from past to current. May be negative.
    var delta: Double { currentE1RM - pastE1RM }
}

// MARK: - Recent PR Entry

/// A PR with the exercise name and previous-best value for delta display.
/// `previousValue` is nil when this PR is the user's first record of this
/// type for that exercise.
struct RecentPREntry: Identifiable, Sendable {
    let record: PersonalRecord
    let exerciseName: String
    let previousValue: Double?

    var id: UUID { record.id }

    /// Absolute difference vs the previous best. Nil when there is no prior.
    var delta: Double? {
        guard let previousValue else { return nil }
        return record.value - previousValue
    }
}

// MARK: - Strength Prediction

struct StrengthPrediction: Sendable {
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

    /// True if we have enough data and a reasonable fit. An R² below 0.5 leaves
    /// most of the variance unexplained, and extrapolating strength linearly is
    /// already optimistic because gains decelerate — so the bar matches the one
    /// the trajectory card applies rather than the looser 0.3 used previously.
    var isReliable: Bool { confidence >= 0.5 }
}

// MARK: - Monthly Stats (Progress tab header)

struct MonthlyStats: Sendable {
    let workouts: Int        // sessions completed this month
    let prCount: Int         // PRs hit this month
    let totalSets: Int       // working sets logged this month
    let avgRPE: Double?      // average RPE across this month's sets
    let previousMonth: PreviousMonthStats?  // for month-over-month deltas
}

struct PreviousMonthStats: Sendable {
    let workouts: Int
    let prCount: Int
    let totalSets: Int
    let avgRPE: Double?
}

// MARK: - Last Workout Recap (top of Progress tab)

/// A lightweight summary of the user's most recent completed session.
/// Powers the "Last Workout" recap card so users can drill straight into
/// their last session from the Progress tab.
struct LastWorkoutRecap: Sendable {
    let sessionId: UUID
    let templateName: String?
    let dayName: String?
    let completedAt: Date
    let durationSeconds: Int
    let workingSets: Int
    let totalVolume: Double
    let prCount: Int
}

// MARK: - Top Lift Trajectory (hero card on Progress tab)

struct TopLiftTrajectory: Identifiable, Sendable {
    let exerciseId: UUID
    let exerciseName: String
    let muscleGroup: String
    let workoutDayId: UUID?
    let dayName: String?
    let sessionCount: Int
    let currentE1RM: Double
    let fourWeekDelta: Double
    let fourWeekDeltaPercent: Double
    let velocityStatus: VelocityStatus
    let weeklyPercent: Double
    let narrative: String
    let sparkline: [Double] // recent e1RM values for the mini chart
    let projection: StrengthPrediction? // 4-week e1RM projection (only when reliable)
    /// Best single-set rep count in the most recent session, used as the
    /// display fallback for bodyweight-only exercises where currentE1RM is 0.
    let bestReps: Int

    /// True when the latest snapshot has no recorded weight — typically a
    /// bodyweight-only movement like dips, pull-ups, or push-ups. Display
    /// surfaces should show "N reps" rather than "0 lb" in this case.
    var isBodyweightOnly: Bool { currentE1RM <= 0 && bestReps > 0 }

    /// Unique ID combining exercise + workout day so the same exercise
    /// on different days appears as distinct entries.
    var id: String {
        "\(exerciseId.uuidString)-\(workoutDayId?.uuidString ?? "global")"
    }

    /// Short status phrase for the trajectory row. Kept terse because the row
    /// already shows the weight and the delta — anything longer truncates at
    /// this width, and the percentage would just restate the number beside it.
    static func buildNarrative(status: VelocityStatus, weeklyPercent: Double, deltaPercent: Double, sessionCount: Int) -> String {
        if sessionCount < 3 {
            return "Building baseline"
        }
        switch status {
        case .accelerating: return "Strong gains"
        case .progressing: return "On track"
        case .maintaining: return "Holding — ready for a push"
        case .stalling: return "Plateau — try a change"
        case .regressing: return "Declining — check recovery"
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
