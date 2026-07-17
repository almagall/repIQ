import Foundation

/// Stable identifiers for every card the Rep Sheet deck can show. Persisted as
/// raw strings in `RepSheetContent.order`, so cases must never be renamed once
/// shipped (add new ones, don't rename).
enum RepSheetCardID: String, Codable, Sendable, CaseIterable {
    case cover
    case strengthGained
    case biggestMover
    case breakthrough
    case prWall
    case allTimeRank
    case consistency
    case relativeStrength
    case muscleBalance
    case monthOverMonth
    case whenYouTrain
    case style
    case nextMonth
}

/// The fully-computed, display-ready payload for one month's Rep Sheet. Built
/// once by `DigestService` at generation time and persisted into the existing
/// `monthly_wrapped.data` JSONB column, then decoded by the deck view — the
/// prior month is closed and immutable, so there's nothing to recompute.
///
/// `order` is the already-selected, already-ordered list of cards to render
/// (cover first, nextMonth last, up to ten total). A card whose gate failed is
/// simply absent from `order` and left nil below. Dates are stored as
/// pre-formatted display strings to avoid depending on the Supabase client's
/// JSONB date strategy.
struct RepSheetContent: Codable, Sendable {
    var order: [RepSheetCardID]

    var cover: Cover?
    var strengthGained: StrengthGained?
    var biggestMover: BiggestMover?
    var breakthrough: Breakthrough?
    var prWall: PRWall?
    var allTimeRank: AllTimeRank?
    var consistency: Consistency?
    var relativeStrength: RelativeStrength?
    var muscleBalance: MuscleBalance?
    var monthOverMonth: MonthOverMonth?
    var whenYouTrain: WhenYouTrain?
    var style: Style?
    var nextMonth: NextMonth?

    // MARK: - Card payloads

    struct Cover: Codable, Sendable {
        var totalSessions: Int
        var totalPRs: Int
        var totalVolume: Double
    }

    struct LiftDelta: Codable, Sendable {
        var exerciseName: String
        var deltaLbs: Double
    }

    struct StrengthGained: Codable, Sendable {
        var totalGainLbs: Double
        var liftCount: Int
        /// Top movers by absolute e1RM gain, biggest first (max 3).
        var topLifts: [LiftDelta]
    }

    struct BiggestMover: Codable, Sendable {
        var exerciseName: String
        var percentGain: Double
        var fromE1RM: Double
        var toE1RM: Double
    }

    struct Breakthrough: Codable, Sendable {
        var exerciseName: String
        var weight: Double
        var reps: Int
        var recordType: String
        var achievedAtDisplay: String
        var priorBest: Double?
        /// Whole weeks the prior best stood before this beat it, if computable.
        var stuckWeeks: Int?
    }

    struct PREntry: Codable, Sendable {
        var exerciseName: String
        var value: Double
        var recordType: String
        var repsAtWeight: Int?
    }

    struct PRWall: Codable, Sendable {
        var count: Int
        var weightPRs: Int
        var repPRs: Int
        /// Up to 5 records, biggest-first.
        var entries: [PREntry]
    }

    struct AllTimeRank: Codable, Sendable {
        /// 1 = best month ever on this metric.
        var rank: Int
        var totalMonths: Int
        var thisValue: Double
        var previousBest: Double
        /// Recent monthly values (oldest→newest) for the bar chart.
        var monthlyValues: [Double]
    }

    struct Consistency: Codable, Sendable {
        var trainedDays: Int
        var restDays: Int
        var bestWeekSessions: Int
        var daysInMonth: Int
        /// 1-indexed day-of-month for each day that had a session.
        var trainedDayNumbers: [Int]
        /// 1-indexed day-of-month for each day a PR was set.
        var prDayNumbers: [Int]
    }

    struct LiftRatio: Codable, Sendable {
        var exerciseName: String
        var ratio: Double
    }

    struct RelativeStrength: Codable, Sendable {
        var bodyweightLbs: Double
        /// The headline lift (highest e1RM), first; up to 4 total.
        var lifts: [LiftRatio]
    }

    struct MuscleBalance: Codable, Sendable {
        var pushVolume: Double
        var pullVolume: Double
        /// push:pull, always >= 1 (larger side over smaller).
        var ratio: Double
        /// True when push dominated, false when pull did — drives the copy.
        var pushDominant: Bool
        var topMuscle: String?
        var bottomMuscle: String?
    }

    struct MonthOverMonth: Codable, Sendable {
        var priorMonthLabel: String
        var thisVolume: Double
        var priorVolume: Double
        var volumeDeltaPct: Double?
        var sessionsDelta: Int
        var e1rmDeltaPct: Double?
    }

    struct WhenYouTrain: Codable, Sendable {
        /// "early", "midday", "evening", or "night".
        var window: String
        var windowPct: Double
        var mostCommonHour: Int
    }

    struct Style: Codable, Sendable {
        var archetype: String
        var avgRPE: Double?
        var hardestRPE: Double?
        var failureSets: Int
    }

    struct NextMonth: Codable, Sendable {
        /// 1–3 forward-looking coaching tips.
        var tips: [String]
        /// "build" for sparse months (habit-forming tone), "optimize" otherwise.
        var tone: String
    }
}
