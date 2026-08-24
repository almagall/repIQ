import Foundation

// MARK: - Set outcome

/// One logged set, against the target it was given.
struct TargetSetResult: Identifiable, Sendable {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rpe: Double?
    let targetWeight: Double
    let targetReps: Int
    /// Nil when the set carried no prescription and so isn't graded — a ramp-up
    /// set on a strength lift, or anything logged beyond the prescribed count.
    let didHit: Bool?

    var id: Int { setNumber }
}

// MARK: - Session

/// One session of this exercise on this day.
struct ExerciseSessionDetail: Identifiable, Sendable {
    let sessionId: UUID
    let date: Date
    let sets: [TargetSetResult]

    var id: UUID { sessionId }

    var graded: [TargetSetResult] { sets.filter { $0.didHit != nil } }
    var setsGraded: Int { graded.count }
    var setsHit: Int { graded.filter { $0.didHit == true }.count }

    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    var isComplete: Bool { setsGraded > 0 && setsHit == setsGraded }

    /// What the engine asked for. Straight sets share one target; a ramp's is
    /// its top set, which is the only set graded anyway.
    var prescribedWeight: Double { graded.map(\.targetWeight).max() ?? 0 }
    var prescribedReps: Int { graded.map(\.targetReps).max() ?? 0 }

    /// Heaviest working set actually lifted.
    var achievedWeight: Double { sets.map(\.weight).max() ?? 0 }

    /// The rep count the engine actually judges: the *minimum* across working
    /// sets, since hypertrophy only advances once every set clears the goal.
    var achievedReps: Int { graded.map(\.reps).min() ?? 0 }

    /// The pair the prescribed-vs-achieved chart plots, chosen by mode.
    ///
    /// Hypertrophy progresses by reps at a fixed load, so charting weight there
    /// draws a flat line and says nothing. Strength ramps to a heavier top set,
    /// so weight is the axis that moves. This mirrors what each mode's state
    /// machine reads to make its decision.
    func chartValues(mode: TrainingMode) -> (goal: Double, actual: Double)? {
        switch mode {
        case .hypertrophy:
            guard prescribedReps > 0, achievedReps > 0 else { return nil }
            return (Double(prescribedReps), Double(achievedReps))
        case .strength:
            guard prescribedWeight > 0, achievedWeight > 0 else { return nil }
            return (prescribedWeight, achievedWeight)
        }
    }
}

// MARK: - Set position

/// How one set position has gone across recent sessions.
///
/// Only meaningful for hypertrophy, where every set carries the same
/// prescription and positions are directly comparable. This is the diagnosis
/// the whole feature is built toward: failing from set 1 means the weight is
/// too heavy, failing only the last set means the volume is.
struct SetPositionStat: Identifiable, Sendable {
    let position: Int
    /// One entry per session, oldest first. Nil where the set wasn't performed.
    let outcomes: [Bool?]

    var id: Int { position }

    var attempted: Int { outcomes.compactMap { $0 }.count }
    var hits: Int { outcomes.compactMap { $0 }.filter { $0 }.count }

    var ratio: Double {
        guard attempted > 0 else { return 0 }
        return Double(hits) / Double(attempted)
    }
}

// MARK: - Next prescription

struct NextPrescription: Sendable {
    let weight: Double
    let reps: Int
    let rpe: Double?
    let decision: ProgressionDecision?
    let trainingMode: TrainingMode

    var goingUp: Bool {
        decision == .increaseWeight || decision == .increaseReps
    }
}

// MARK: - Detail

/// Everything the exercise drill-in shows, scoped to one exercise on one
/// workout day — the same scope the progression engine uses. The same lift on
/// two days has separate targets and separate histories, and merging them is
/// what made the old drill-in chart a sawtooth.
struct ExerciseTargetDetail: Sendable {
    let exerciseId: UUID
    let workoutDayId: UUID?
    let exerciseName: String
    let dayName: String?
    let trainingMode: TrainingMode
    /// Oldest first.
    let sessions: [ExerciseSessionDetail]
    let next: NextPrescription?

    var setsGraded: Int { sessions.reduce(0) { $0 + $1.setsGraded } }
    var setsHit: Int { sessions.reduce(0) { $0 + $1.setsHit } }

    var ratio: Double {
        guard setsGraded > 0 else { return 0 }
        return Double(setsHit) / Double(setsGraded)
    }

    var hasData: Bool { !sessions.isEmpty }

    struct ChartPoint: Sendable {
        let goal: Double
        let actual: Double
    }

    /// Sessions the prescribed-vs-achieved chart can actually plot. Sessions
    /// with no usable prescription are dropped rather than plotted at zero —
    /// doing the latter dragged the line to the floor and turned a flat series
    /// into a meaningless shape.
    var chartPoints: [ChartPoint] {
        sessions.compactMap { session in
            session.chartValues(mode: trainingMode)
                .map { ChartPoint(goal: $0.goal, actual: $0.actual) }
        }
    }

    /// Set positions across sessions, for the "where you miss" grid. Empty for
    /// strength, where only the top set is graded and positions aren't
    /// comparable — a ramp set and a top set are different jobs.
    var setPositions: [SetPositionStat] {
        guard trainingMode == .hypertrophy else { return [] }
        let maxPosition = sessions.flatMap { $0.graded.map(\.setNumber) }.max() ?? 0
        guard maxPosition > 0 else { return [] }

        return (1...maxPosition).map { position in
            SetPositionStat(
                position: position,
                outcomes: sessions.map { session in
                    session.graded.first { $0.setNumber == position }?.didHit
                }
            )
        }
    }

    /// Where the misses cluster, which is the difference between a load problem
    /// and a volume problem. Nil when there's nothing to say.
    enum Diagnosis: Sendable {
        /// Missing while still fresh — the prescribed weight is wrong.
        case tooHeavy
        /// Early sets land, later ones don't — the load is fine, the volume isn't.
        case tooMuchVolume(firstFailing: Int)
        /// Meeting everything, repeatedly. The prescription is behind the lifter.
        case targetTooSoft
        /// Strength lift missing its top set.
        case topSetMissed
    }

    var diagnosis: Diagnosis? {
        guard setsGraded >= 4 else { return nil }

        if trainingMode == .strength {
            return ratio < 0.6 ? .topSetMissed : (ratio >= 0.95 ? .targetTooSoft : nil)
        }

        if ratio >= 0.95, sessions.count >= 3 { return .targetTooSoft }
        guard ratio < 0.8 else { return nil }

        let positions = setPositions.filter { $0.attempted > 0 }
        guard let first = positions.first else { return nil }

        // A first set that lands consistently means the weight is provably
        // manageable, so the shortfall is room rather than load.
        if first.ratio >= 0.8,
           let failing = positions.first(where: { $0.ratio < 0.5 }) {
            return .tooMuchVolume(firstFailing: failing.position)
        }
        if first.ratio < 0.6 { return .tooHeavy }
        return nil
    }
}
