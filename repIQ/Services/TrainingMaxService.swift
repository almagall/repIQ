import Foundation
import Supabase

struct TrainingMaxService: Sendable {

    /// The current (latest) training max per exercise, for the ones that have one.
    func fetchLatest(userId: UUID, exerciseIds: [UUID]) async throws -> [UUID: TrainingMax] {
        guard !exerciseIds.isEmpty else { return [:] }
        let rows: [TrainingMax] = try await supabase.from("training_maxes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("exercise_id", values: exerciseIds.map(\.uuidString))
            .order("created_at", ascending: false)
            .execute()
            .value

        var result: [UUID: TrainingMax] = [:]
        for row in rows where result[row.exerciseId] == nil {
            result[row.exerciseId] = row
        }
        return result
    }

    /// Every TM ever set for a lift, oldest first — the TM line on a chart.
    func fetchHistory(userId: UUID, exerciseId: UUID) async throws -> [TrainingMax] {
        try await supabase.from("training_maxes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("exercise_id", value: exerciseId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    @discardableResult
    func insert(userId: UUID, exerciseId: UUID, value: Double, source: TrainingMax.Source) async throws -> TrainingMax {
        struct Row: Encodable {
            let user_id: String
            let exercise_id: String
            let value: Double
            let source: String
        }
        return try await supabase.from("training_maxes")
            .insert(Row(user_id: userId.uuidString, exercise_id: exerciseId.uuidString, value: value, source: source.rawValue))
            .select()
            .single()
            .execute()
            .value
    }

    struct OneRepMaxEstimate: Sendable {
        let oneRepMax: Double
        let weight: Double
        let reps: Int
    }

    /// Best Epley e1RM across every completed working set of this lift, so the
    /// TM card can open prefilled instead of asking cold.
    func estimateOneRepMax(userId: UUID, exerciseId: UUID) async throws -> OneRepMaxEstimate? {
        struct SetRow: Decodable {
            let weight: Double
            let reps: Int
        }
        let rows: [SetRow] = try await supabase.from("workout_sets")
            .select("weight, reps, workout_sessions!inner(user_id, status)")
            .eq("workout_sessions.user_id", value: userId.uuidString)
            .eq("workout_sessions.status", value: "completed")
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("set_type", value: "working")
            .gt("weight", value: 0)
            .gt("reps", value: 0)
            .execute()
            .value

        func e1rm(_ row: SetRow) -> Double { row.weight * (1.0 + Double(row.reps) / 30.0) }
        guard let best = rows.max(by: { e1rm($0) < e1rm($1) }) else { return nil }
        return OneRepMaxEstimate(oneRepMax: e1rm(best), weight: best.weight, reps: best.reps)
    }
}
