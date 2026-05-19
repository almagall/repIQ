import Foundation
import Supabase

/// Writes and reads short-lived "training now" presence rows. Owners upsert
/// when a workout starts (and ideally refresh every few minutes); rows
/// auto-expire 2h after their last update. Friends can read other rows via
/// the RLS policy in migration 20260518_shared_templates_and_presence.sql.
struct PresenceService: Sendable {

    /// Marks the user as actively training. Idempotent — repeated calls
    /// just push the expiry forward. Pass the user's current gym placeId
    /// so the Gym Hub query can filter to gym-mates.
    func setTraining(userId: UUID, gymPlaceId: String?) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let expires = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(2 * 60 * 60)
        )
        try await supabase.from("user_presence")
            .upsert(PresenceUpsertPayload(
                user_id: userId.uuidString,
                gym_place_id: gymPlaceId,
                started_at: now,
                expires_at: expires
            ))
            .execute()
    }

    /// Clears the user's presence (workout finished or abandoned).
    func clear(userId: UUID) async throws {
        try await supabase.from("user_presence")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Returns presence rows for the given friend ids that haven't yet
    /// expired. The RLS policy already constrains visibility to accepted
    /// friendships; this query is just the friend-id filter and TTL check.
    func fetchFriendsTraining(friendIds: [UUID]) async throws -> [TrainingNowEntry] {
        guard !friendIds.isEmpty else { return [] }
        let now = ISO8601DateFormatter().string(from: Date())
        return try await supabase.from("user_presence")
            .select()
            .in("user_id", values: friendIds.map(\.uuidString))
            .gt("expires_at", value: now)
            .execute()
            .value
    }
}

/// Snapshot of a friend's active workout used by the Gym Hub banner. Maps
/// 1:1 with a `user_presence` row.
struct TrainingNowEntry: Codable, Identifiable, Sendable {
    let userId: UUID
    let gymPlaceId: String?
    let startedAt: Date
    let expiresAt: Date

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case gymPlaceId = "gym_place_id"
        case startedAt = "started_at"
        case expiresAt = "expires_at"
    }
}

private nonisolated struct PresenceUpsertPayload: Encodable, Sendable {
    let user_id: String
    let gym_place_id: String?
    let started_at: String
    let expires_at: String
}
