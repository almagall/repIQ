import Foundation

/// The two numbers that must be identical everywhere "targets going up" is
/// reported, or the Progress tab's headline stops agreeing with its own rows.
enum AdherenceRules {
    /// Measurement window, in days.
    static let windowDays = 28
    /// Sessions a lift needs before its latest decision is counted.
    static let minSessions = 3
}

// MARK: - Session

/// How one exercise went in one session, measured against what it was told to do.
///
/// For hypertrophy every working set counts, since they all carry the same
/// prescription. For strength only the top set counts — the ramp-up sets are
/// meant to feel easy, and the top set is the one the progression engine reads
/// to decide what to prescribe next. Grading a ramp set the same way would
/// produce a number the engine disagrees with.
struct SessionAdherence: Identifiable, Sendable {
    let sessionId: UUID
    let date: Date
    let setsGraded: Int
    let setsHit: Int

    var id: UUID { sessionId }

    /// 0...1. Zero when nothing landed; a session with no graded sets never
    /// reaches this type at all.
    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    /// Every prescribed set met. Drives the green capsule.
    var isComplete: Bool { setsGraded > 0 && setsHit == setsGraded }
}

// MARK: - Exercise

/// One exercise on one workout day. The same exercise trained on two days is
/// two of these — they have independent targets and independent histories.
struct ExerciseAdherence: Identifiable, Sendable {
    let exerciseId: UUID
    let workoutDayId: UUID?
    let exerciseName: String
    let trainingMode: TrainingMode
    /// The engine's most recent call for this lift, which describes the *next*
    /// session rather than the last one.
    let latestDecision: ProgressionDecision?
    /// Oldest first, so the capsule row reads left-to-right in time.
    let sessions: [SessionAdherence]

    var id: String {
        "\(exerciseId.uuidString)-\(workoutDayId?.uuidString ?? "unplanned")"
    }

    var setsGraded: Int { sessions.reduce(0) { $0 + $1.setsGraded } }
    var setsHit: Int { sessions.reduce(0) { $0 + $1.setsHit } }

    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    /// Whether the next prescription asks for more weight or more reps.
    var targetGoingUp: Bool {
        latestDecision == .increaseWeight || latestDecision == .increaseReps
    }

    /// Enough history for the engine's decision to mean anything. Matches the
    /// `minSessions` gate in `fetchProgressionRate` — the hero and these rows
    /// report the same thing and have to count the same lifts, or the headline
    /// contradicts the rows beneath it.
    var hasEnoughHistory: Bool { sessions.count >= AdherenceRules.minSessions }

    var lastTrained: Date? { sessions.last?.date }
}

// MARK: - Day

/// One workout day — the unit the overview groups by, because targets and
/// progression are both scoped to it.
struct DayAdherence: Identifiable, Sendable {
    /// Nil for sets logged outside any plan. Those have no prescription, so the
    /// day renders without an adherence figure.
    let workoutDayId: UUID?
    let dayName: String
    let exercises: [ExerciseAdherence]
    let sessionCount: Int
    /// Same figure over the preceding window, for "up from 68%". Nil when
    /// there isn't a full prior window to compare against.
    let previousRatio: Double?

    var id: String { workoutDayId?.uuidString ?? "unplanned" }

    var setsGraded: Int { exercises.reduce(0) { $0 + $1.setsGraded } }
    var setsHit: Int { exercises.reduce(0) { $0 + $1.setsHit } }

    /// Literally hits ÷ graded, so the fraction printed beside it always agrees
    /// with it. Strength lifts contribute only their top set to both halves,
    /// which is what keeps a 5-set accessory from outweighing a heavy single.
    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    var hasTargets: Bool { setsGraded > 0 }

    var lastTrained: Date? {
        exercises.compactMap(\.lastTrained).max()
    }

    /// Lifts on this day with enough history for the engine to have a view.
    /// Everything below is counted over these, not over every exercise logged —
    /// summing across days then reconciles with the hero's fraction.
    var trackedExercises: [ExerciseAdherence] {
        exercises.filter(\.hasEnoughHistory)
    }

    var targetsGoingUp: Int { trackedExercises.filter(\.targetGoingUp).count }

    /// Percentage-point change vs the previous window. Nil when there's no
    /// prior window, which is the normal state for a young account.
    var change: Double? {
        guard let previousRatio else { return nil }
        return (ratio - previousRatio) * 100
    }
}

// MARK: - Report

/// Everything the Progress overview needs about targets, in one value.
struct AdherenceReport: Sendable {
    let days: [DayAdherence]
    /// Completed sessions inside the window. Context for how much the
    /// percentage is standing on — 82% over three sessions is a thinner claim
    /// than 82% over fourteen.
    let sessionCount: Int
    let windowDays: Int
    let lastTrained: Date?

    var setsGraded: Int { days.reduce(0) { $0 + $1.setsGraded } }
    var setsHit: Int { days.reduce(0) { $0 + $1.setsHit } }

    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    /// No graded sets anywhere — a brand-new account, or one that has only
    /// logged sessions the engine never prescribed for.
    var isEmpty: Bool { setsGraded == 0 }

    /// Days worth showing first: worst adherence leads, and days with no
    /// targets sink to the bottom.
    var daysByAttention: [DayAdherence] {
        days.sorted { lhs, rhs in
            if lhs.hasTargets != rhs.hasTargets { return lhs.hasTargets }
            return lhs.ratio < rhs.ratio
        }
    }

    static let empty = AdherenceReport(
        days: [], sessionCount: 0, windowDays: 28, lastTrained: nil
    )
}

// MARK: - Display helpers

extension Double {
    /// Adherence ratios are always shown as whole percentages — a decimal point
    /// implies a precision that a count of sets doesn't have.
    var adherencePercent: Int { Int((self * 100).rounded()) }
}
