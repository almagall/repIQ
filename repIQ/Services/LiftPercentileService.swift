import Foundation
import Supabase

/// Computes a user's e1RM percentile on a specific exercise. Two scopes:
/// - friends: client-side, uses the friend's best working-set e1RM in 90d
/// - league tier: server-side RPC `lift_percentile_in_tier` (migration
///   `20260518_lift_percentiles.sql`)
struct LiftPercentileService: Sendable {

    /// Returns the user's percentile rank (0–100) among friends on the
    /// given exercise. Returns nil if the cohort is smaller than 3 — too
    /// few people for a meaningful comparison.
    func friendsPercentile(
        exerciseId: UUID,
        userE1RM: Double,
        friendIds: [UUID]
    ) async throws -> Int? {
        guard !friendIds.isEmpty else { return nil }

        // Pull the relevant working sets for every friend in the last 90
        // days, then take each friend's max e1RM client-side. A server-side
        // RPC would be slimmer but this keeps the migration surface small.
        struct SetRow: Decodable {
            let weight: Double
            let reps: Int
            let session_id: UUID
        }
        struct SessionRow: Decodable {
            let id: UUID
            let user_id: UUID
        }

        let ninetyDaysAgo = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(-90 * 24 * 60 * 60)
        )

        // First fetch friend sessions for filtering
        let sessions: [SessionRow] = try await supabase.from("workout_sessions")
            .select("id, user_id")
            .in("user_id", values: friendIds.map(\.uuidString))
            .gte("completed_at", value: ninetyDaysAgo)
            .execute()
            .value
        let sessionToUser = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.user_id) })

        let sessionIds = sessions.map(\.id)
        guard !sessionIds.isEmpty else { return nil }

        let sets: [SetRow] = try await supabase.from("workout_sets")
            .select("weight, reps, session_id")
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("set_type", value: "working")
            .gt("weight", value: 0)
            .gt("reps", value: 0)
            .in("session_id", values: sessionIds.map(\.uuidString))
            .execute()
            .value

        var bestByUser: [UUID: Double] = [:]
        for set in sets {
            guard let userId = sessionToUser[set.session_id] else { continue }
            let e1rm = set.weight * (1.0 + Double(set.reps) / 30.0)
            bestByUser[userId] = max(bestByUser[userId] ?? 0, e1rm)
        }

        let total = bestByUser.count
        guard total >= 3 else { return nil }

        let below = bestByUser.values.filter { $0 <= userE1RM }.count
        return Int(round(Double(below) / Double(total) * 100))
    }

    /// Returns the user's percentile rank (0–100) among all users in the
    /// given league tier on this exercise. Wraps the
    /// `lift_percentile_in_tier` RPC; returns nil if the RPC returns null
    /// (cohort < 5) or if the RPC isn't deployed yet.
    func tierPercentile(
        exerciseId: UUID,
        userE1RM: Double,
        tier: LeagueTier
    ) async throws -> Int? {
        let raw: Int? = try await supabase.rpc(
            "lift_percentile_in_tier",
            params: LiftPercentileRPCParams(
                p_exercise_id: exerciseId.uuidString,
                p_user_e1rm: userE1RM,
                p_tier: tier.rawValue
            )
        )
        .execute()
        .value
        return raw
    }
}

/// RPC params struct. `nonisolated` is required because the project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which otherwise makes the
/// Encodable conformance main-actor-isolated and fails the Sendable
/// requirement of `PostgrestRpcBuilder.params`.
private nonisolated struct LiftPercentileRPCParams: Encodable, Sendable {
    let p_exercise_id: String
    let p_user_e1rm: Double
    let p_tier: String
}
