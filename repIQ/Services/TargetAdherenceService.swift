import Foundation
import Supabase

/// Builds the Progress tab's answer to "did you do what you were told?".
///
/// Reads logged sets against the targets stored beside them, rolls the result
/// up per exercise-and-day, and reports it alongside the engine's latest
/// decision for each lift. Two measurements live here on purpose: adherence
/// (did you hit it) and progression (is the next target higher). They come
/// apart constantly — a soft prescription produces high adherence and no
/// progress — so neither is derived from the other.
struct TargetAdherenceService {

    private let progressionService = ProgressionService()

    // MARK: - Public

    /// - Parameter windowDays: how far back to measure. The same span
    ///   immediately before it is measured too, to produce "up from 68%".
    func fetchReport(userId: UUID, windowDays: Int = 28) async throws -> AdherenceReport {
        let calendar = Calendar.current
        let now = Date()
        guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now),
              let priorStart = calendar.date(byAdding: .day, value: -windowDays * 2, to: now)
        else { return .empty }

        let sessions = try await fetchSessions(userId: userId, since: priorStart)
        guard !sessions.isEmpty else { return .empty }

        let sets = try await fetchWorkingSets(sessionIds: sessions.map(\.id))
        guard !sets.isEmpty else {
            return AdherenceReport(
                days: [], sessionCount: sessions.filter { $0.date >= windowStart }.count,
                windowDays: windowDays,
                lastTrained: sessions.map(\.date).max()
            )
        }

        let setsBySession = Dictionary(grouping: sets, by: \.sessionId)

        // The engine's own record, full history rather than just the latest row.
        // Every entry is both a decision *and* the prescription the following
        // session was given, which is what lets sessions logged before targets
        // were stored be graded at all.
        let log = try await fetchProgressionLog(userId: userId, since: priorStart)

        var current: [GroupKey: [SessionAdherence]] = [:]
        var prior: [GroupKey: [SessionAdherence]] = [:]

        for session in sessions {
            guard let sessionSets = setsBySession[session.id] else { continue }
            let byExercise = Dictionary(grouping: sessionSets, by: \.exerciseId)

            for (exerciseId, exerciseSets) in byExercise {
                let key = GroupKey(exerciseId: exerciseId, workoutDayId: session.workoutDayId)
                let reconstructed = log.prescription(for: key, before: session.startedAt)
                let mode = reconstructed?.mode
                    ?? log.latest[key]?.mode
                    ?? inferredMode(from: exerciseSets)

                let graded = gradedSets(
                    exerciseSets,
                    mode: mode,
                    fallback: reconstructed
                )
                guard !graded.isEmpty else { continue }

                let entry = SessionAdherence(
                    sessionId: session.id,
                    date: session.date,
                    setsGraded: graded.count,
                    setsHit: graded.filter(\.didHit).count
                )
                if session.date >= windowStart {
                    current[key, default: []].append(entry)
                } else {
                    prior[key, default: []].append(entry)
                }
            }
        }

        guard !current.isEmpty else {
            return AdherenceReport(
                days: [], sessionCount: 0, windowDays: windowDays,
                lastTrained: sessions.map(\.date).max()
            )
        }

        let names = try await fetchExerciseNames(ids: Set(current.keys.map(\.exerciseId)))
        let dayNames = try await fetchDayNames(ids: Set(current.keys.compactMap(\.workoutDayId)))

        let days = buildDays(
            current: current,
            prior: prior,
            latest: log.latest,
            exerciseNames: names,
            dayNames: dayNames
        )

        return AdherenceReport(
            days: days,
            sessionCount: sessions.filter { $0.date >= windowStart }.count,
            windowDays: windowDays,
            lastTrained: sessions.map(\.date).max()
        )
    }

    /// One exercise on one workout day, set by set.
    ///
    /// Scoped by day because that's how the engine scopes targets — the same
    /// lift on Push A and Push B has independent prescriptions, and charting
    /// them together produces a sawtooth that describes nobody's training.
    ///
    /// - Parameter sessionLimit: how many recent sessions to return. The grid
    ///   and the chart both read left-to-right in time and stop being legible
    ///   much past this.
    func fetchExerciseDetail(
        userId: UUID,
        exerciseId: UUID,
        workoutDayId: UUID?,
        sessionLimit: Int = 8
    ) async throws -> ExerciseTargetDetail? {
        // Reach well past the adherence window: a drill-in should show a lift's
        // recent history even if it hasn't been trained inside the last month.
        guard let since = Calendar.current.date(byAdding: .day, value: -240, to: Date())
        else { return nil }

        let allSessions = try await fetchSessions(userId: userId, since: since)
        let sessions = allSessions.filter { $0.workoutDayId == workoutDayId }
        guard !sessions.isEmpty else { return nil }

        let sets = try await fetchWorkingSets(sessionIds: sessions.map(\.id))
            .filter { $0.exerciseId == exerciseId }
        guard !sets.isEmpty else { return nil }

        let log = try await fetchProgressionLog(userId: userId, since: since)
        let key = GroupKey(exerciseId: exerciseId, workoutDayId: workoutDayId)
        let setsBySession = Dictionary(grouping: sets, by: \.sessionId)

        var details: [ExerciseSessionDetail] = []
        var mode: TrainingMode = log.latest[key]?.mode ?? .hypertrophy

        for session in sessions {
            guard let sessionSets = setsBySession[session.id], !sessionSets.isEmpty else { continue }
            let prescription = log.prescription(for: key, before: session.startedAt)
            let sessionMode = prescription?.mode ?? mode
            mode = sessionMode

            // Which sets this mode grades — the same rule the rollup uses, so a
            // lift's drill-in can never disagree with its row on the overview.
            let graded = Set(
                gradedSets(sessionSets, mode: sessionMode, fallback: prescription)
                    .map(\.setNumber)
            )

            let outcomes: [TargetSetResult] = sessionSets
                .sorted { $0.setNumber < $1.setNumber }
                .map { set in
                    let targetWeight = set.targetWeight ?? prescription?.weight ?? 0
                    let targetReps = set.targetReps ?? prescription?.reps ?? 0
                    let isGraded = graded.contains(set.setNumber) && targetReps > 0
                    return TargetSetResult(
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        rpe: set.rpe,
                        targetWeight: targetWeight,
                        targetReps: targetReps,
                        didHit: isGraded
                            ? (set.weight >= targetWeight && set.reps >= targetReps)
                            : nil
                    )
                }

            details.append(
                ExerciseSessionDetail(
                    sessionId: session.id,
                    date: session.date,
                    sets: outcomes
                )
            )
        }

        guard !details.isEmpty else { return nil }
        let recent = Array(details.suffix(sessionLimit))

        let names = try await fetchExerciseNames(ids: [exerciseId])
        let dayNames = try await fetchDayNames(ids: Set([workoutDayId].compactMap { $0 }))
        let latest = log.latest[key]

        return ExerciseTargetDetail(
            exerciseId: exerciseId,
            workoutDayId: workoutDayId,
            exerciseName: names[exerciseId] ?? "Exercise",
            dayName: workoutDayId.flatMap { dayNames[$0] },
            trainingMode: latest?.mode ?? mode,
            sessions: recent,
            next: latest.map {
                NextPrescription(
                    weight: $0.weight,
                    reps: $0.reps,
                    rpe: nil,
                    decision: $0.decision,
                    trainingMode: $0.mode
                )
            }
        )
    }

    // MARK: - Mode-aware set selection

    /// Grades an exercise's working sets for one session.
    ///
    /// A set is graded against the target stored beside it. When there isn't one
    /// — every session logged before targets were persisted — the prescription
    /// is reconstructed from the `progression_log` entry that was in force at
    /// the time. That reconstruction is exact for everything this service
    /// actually grades: hypertrophy prescribes one weight and rep goal across
    /// all working sets, and strength is judged on its top set alone. The only
    /// thing `progression_log` can't reproduce is the individual ramp-up
    /// weights, and those were never graded.
    ///
    /// Hypertrophy counts every working set, since they all carry the same
    /// prescription and are directly comparable. Ramped strength counts one.
    /// Straight-set strength counts every set for the same reason hypertrophy
    /// does; it is recognised by its *stored* targets all sharing one weight
    /// (the scheme itself isn't in `progression_log`). Reconstructed sessions
    /// also share one weight but predate straight sets, so they keep the
    /// top-set rule.
    private func gradedSets(
        _ sets: [WorkingSet],
        mode: TrainingMode,
        fallback: Prescription?
    ) -> [GradedSet] {
        let resolved: [GradedSet] = sets.compactMap { set in
            let targetWeight = set.targetWeight ?? fallback?.weight
            let targetReps = set.targetReps ?? fallback?.reps
            guard let targetReps, targetReps > 0 else { return nil }
            let weight = targetWeight ?? 0
            return GradedSet(
                setNumber: set.setNumber,
                targetWeight: weight,
                actualWeight: set.weight,
                didHit: set.weight >= weight && set.reps >= targetReps
            )
        }

        switch mode {
        case .hypertrophy:
            return resolved
        case .strength:
            let storedWeights = Set(sets.compactMap(\.targetWeight))
            if storedWeights.count == 1, sets.allSatisfy({ $0.targetWeight != nil }), resolved.count > 1 {
                return resolved
            }
            // Prefer the heaviest *prescribed* load, so a session the lifter
            // came in under doesn't promote a ramp set into the top-set slot.
            // Reconstructed sessions share one prescribed weight across every
            // set, so they fall back to the heaviest set actually lifted, which
            // is the top set by definition of a ramp.
            let prescribedTop = resolved.map(\.targetWeight).max() ?? 0
            let candidates = resolved.filter { $0.targetWeight == prescribedTop }
            if candidates.count == 1 { return candidates }
            guard let heaviest = candidates.max(by: { $0.actualWeight < $1.actualWeight })
            else { return [] }
            return [heaviest]
        }
    }

    /// Fallback when an exercise has no `progression_log` history at all — a
    /// session from before the engine had anything to prescribe from. Straight
    /// sets share one working weight; a ramp doesn't.
    private func inferredMode(from sets: [WorkingSet]) -> TrainingMode {
        let weights = Set(sets.map(\.weight))
        return weights.count > 1 ? .strength : .hypertrophy
    }

    // MARK: - Assembly

    private func buildDays(
        current: [GroupKey: [SessionAdherence]],
        prior: [GroupKey: [SessionAdherence]],
        latest: [GroupKey: Prescription],
        exerciseNames: [UUID: String],
        dayNames: [UUID: String]
    ) -> [DayAdherence] {
        let byDay = Dictionary(grouping: current.keys, by: \.workoutDayId)

        return byDay.compactMap { dayId, keys -> DayAdherence? in
            let exercises: [ExerciseAdherence] = keys.compactMap { key -> ExerciseAdherence? in
                guard let sessions = current[key], !sessions.isEmpty else { return nil }
                return ExerciseAdherence(
                    exerciseId: key.exerciseId,
                    workoutDayId: key.workoutDayId,
                    exerciseName: exerciseNames[key.exerciseId] ?? "Exercise",
                    trainingMode: latest[key]?.mode ?? .hypertrophy,
                    latestDecision: latest[key]?.decision,
                    sessions: sessions.sorted { $0.date < $1.date }
                )
            }
            .sorted { $0.ratio < $1.ratio }

            guard !exercises.isEmpty else { return nil }

            // Prior-window ratio for the same day, counted the same way.
            let priorSessions = keys.flatMap { prior[$0] ?? [] }
            let priorGraded = priorSessions.reduce(0) { $0 + $1.setsGraded }
            let priorHit = priorSessions.reduce(0) { $0 + $1.setsHit }
            let previousRatio = priorGraded > 0
                ? Double(priorHit) / Double(priorGraded)
                : nil

            let sessionIds = Set(exercises.flatMap { $0.sessions.map(\.sessionId) })

            return DayAdherence(
                workoutDayId: dayId,
                dayName: dayId.flatMap { dayNames[$0] } ?? "Unplanned",
                exercises: exercises,
                sessionCount: sessionIds.count,
                previousRatio: previousRatio
            )
        }
    }

    // MARK: - Fetches

    private func fetchSessions(userId: UUID, since: Date) async throws -> [SessionRef] {
        struct Row: Decodable {
            let id: String
            let workout_day_id: String?
            let completed_at: String?
            let started_at: String
        }

        let rows: [Row] = try await supabase.from("workout_sessions")
            .select("id,workout_day_id,completed_at,started_at")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("started_at", value: iso.string(from: since))
            .order("started_at", ascending: true)
            .execute()
            .value

        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.id) else { return nil }
            let started = parseDate(row.started_at) ?? Date()
            let date = row.completed_at.flatMap(parseDate) ?? started
            return SessionRef(
                id: id,
                workoutDayId: row.workout_day_id.flatMap(UUID.init(uuidString:)),
                date: date,
                startedAt: started
            )
        }
    }

    /// All working sets, with whatever target was stored beside them. Sets
    /// without one are reconstructed later rather than dropped here — dropping
    /// them is what made this feature invisible on accounts with real history.
    private func fetchWorkingSets(sessionIds: [UUID]) async throws -> [WorkingSet] {
        guard !sessionIds.isEmpty else { return [] }

        struct Row: Decodable {
            let session_id: String
            let exercise_id: String
            let set_number: Int
            let weight: Double
            let reps: Int
            let rpe: Double?
            let target_weight: Double?
            let target_reps: Int?
        }

        let rows: [Row] = try await supabase.from("workout_sets")
            .select("session_id,exercise_id,set_number,weight,reps,rpe,target_weight,target_reps")
            .in("session_id", values: sessionIds.map(\.uuidString))
            .eq("set_type", value: "working")
            .order("set_number", ascending: true)
            .execute()
            .value

        return rows.compactMap { row in
            guard let sessionId = UUID(uuidString: row.session_id),
                  let exerciseId = UUID(uuidString: row.exercise_id) else { return nil }
            return WorkingSet(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setNumber: row.set_number,
                weight: row.weight,
                reps: row.reps,
                rpe: row.rpe,
                targetWeight: row.target_weight,
                targetReps: row.target_reps
            )
        }
    }

    /// The engine's full record over the window, ordered oldest-first per lift.
    ///
    /// Each row carries both the decision and the prescription it produced, and
    /// is written at the *end* of a session to describe the next one — so the
    /// row that applies to a given session is the last one recorded before that
    /// session started.
    private func fetchProgressionLog(userId: UUID, since: Date) async throws -> ProgressionHistory {
        struct Row: Decodable {
            let exercise_id: String
            let workout_day_id: String?
            let decision: String
            let training_mode: String
            let target_weight: Double
            let target_reps_low: Int
            let created_at: String
        }

        // Reach back beyond the comparison window: a lift trained infrequently
        // may have had its current prescription set months ago, and without the
        // earlier row its recent sessions would have nothing to grade against.
        let reach = Calendar.current.date(byAdding: .day, value: -120, to: since) ?? since

        let rows: [Row] = try await supabase.from("progression_log")
            .select("exercise_id,workout_day_id,decision,training_mode,target_weight,target_reps_low,created_at")
            .eq("user_id", value: userId.uuidString)
            .gte("created_at", value: iso.string(from: reach))
            .order("created_at", ascending: true)
            .execute()
            .value

        var byKey: [GroupKey: [Prescription]] = [:]
        for row in rows {
            guard let exerciseId = UUID(uuidString: row.exercise_id),
                  let date = parseDate(row.created_at) else { continue }
            let key = GroupKey(
                exerciseId: exerciseId,
                workoutDayId: row.workout_day_id.flatMap(UUID.init(uuidString:))
            )
            byKey[key, default: []].append(
                Prescription(
                    recordedAt: date,
                    weight: row.target_weight,
                    reps: row.target_reps_low,
                    mode: TrainingMode(rawValue: row.training_mode) ?? .hypertrophy,
                    decision: ProgressionDecision(rawValue: row.decision)
                )
            )
        }
        return ProgressionHistory(byKey: byKey)
    }

    private func fetchExerciseNames(ids: Set<UUID>) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        struct Row: Decodable { let id: String; let name: String }

        let rows: [Row] = try await supabase.from("exercises")
            .select("id,name")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value

        return rows.reduce(into: [:]) { dict, row in
            if let id = UUID(uuidString: row.id) { dict[id] = row.name }
        }
    }

    private func fetchDayNames(ids: Set<UUID>) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        struct Row: Decodable { let id: String; let name: String }

        let rows: [Row] = try await supabase.from("workout_days")
            .select("id,name")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value

        return rows.reduce(into: [:]) { dict, row in
            if let id = UUID(uuidString: row.id) { dict[id] = row.name }
        }
    }

    // MARK: - Internal types

    private struct GroupKey: Hashable {
        let exerciseId: UUID
        let workoutDayId: UUID?
    }

    /// One `progression_log` entry: the decision, and the prescription it set
    /// for the session that followed.
    private struct Prescription {
        let recordedAt: Date
        let weight: Double
        let reps: Int
        let mode: TrainingMode
        let decision: ProgressionDecision?
    }

    private struct ProgressionHistory {
        /// Oldest-first per lift.
        let byKey: [GroupKey: [Prescription]]

        /// The prescription in force when a session began — the last one
        /// recorded before it started. Start rather than completion, because
        /// the row this session itself produced lands at its completion time
        /// and describes the *next* session, not this one.
        func prescription(for key: GroupKey, before date: Date) -> Prescription? {
            byKey[key]?.last { $0.recordedAt < date }
        }

        var latest: [GroupKey: Prescription] {
            byKey.compactMapValues(\.last)
        }
    }

    private struct SessionRef {
        let id: UUID
        let workoutDayId: UUID?
        /// Completion time — what the UI dates a session by.
        let date: Date
        /// Used to pick the prescription that was in force; see `prescription(for:before:)`.
        let startedAt: Date
    }

    private struct WorkingSet {
        let sessionId: UUID
        let exerciseId: UUID
        let setNumber: Int
        let weight: Double
        let reps: Int
        let rpe: Double?
        let targetWeight: Double?
        let targetReps: Int?
    }

    private struct GradedSet {
        let setNumber: Int
        let targetWeight: Double
        let actualWeight: Double
        let didHit: Bool
    }

    // MARK: - Dates

    private var iso: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    /// Supabase returns timestamps with and without fractional seconds
    /// depending on the column, so both are tried.
    private func parseDate(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}
