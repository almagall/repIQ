import Foundation
import Supabase

/// Manages social profiles, friendships, and user search.
struct SocialService: Sendable {

    // MARK: - Social Profile

    /// Fetches the full social profile for a user (includes social fields).
    func fetchSocialProfile(userId: UUID) async throws -> SocialProfile {
        try await supabase.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    /// Updates social profile fields (username, bio, avatar, privacy).
    func updateSocialProfile(userId: UUID, username: String?, bio: String?, privacyLevel: PrivacyLevel) async throws {
        struct UpdatePayload: Encodable {
            let username: String?
            let bio: String?
            let privacy_level: String
        }

        try await supabase.from("profiles")
            .update(UpdatePayload(
                username: username,
                bio: bio,
                privacy_level: privacyLevel.rawValue
            ))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Searches users by username or display name.
    func searchUsers(query: String, currentUserId: UUID) async throws -> [SocialProfile] {
        guard !query.isEmpty else { return [] }

        let results: [SocialProfile] = try await supabase.from("profiles")
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .neq("id", value: currentUserId.uuidString)
            .limit(20)
            .execute()
            .value

        return results
    }

    // MARK: - Friendships

    /// Sends a friend request.
    func sendFriendRequest(from userId: UUID, to friendId: UUID) async throws {
        struct CreateFriendship: Encodable {
            let user_id: String
            let friend_id: String
            let status: String
        }

        try await supabase.from("friendships")
            .insert(CreateFriendship(
                user_id: userId.uuidString,
                friend_id: friendId.uuidString,
                status: "pending"
            ))
            .execute()
    }

    /// Accepts a friend request.
    func acceptFriendRequest(friendshipId: UUID) async throws {
        try await supabase.from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    /// Declines a friend request.
    func declineFriendRequest(friendshipId: UUID) async throws {
        try await supabase.from("friendships")
            .update(["status": "declined"])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    /// Removes a friendship (unfriend).
    func removeFriendship(friendshipId: UUID) async throws {
        try await supabase.from("friendships")
            .delete()
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    /// Fetches all accepted friends for a user with their profiles.
    func fetchFriends(userId: UUID) async throws -> [Friendship] {
        // Friendships where user is the sender — join friend's profile
        let sent: [Friendship] = try await supabase.from("friendships")
            .select("*, profiles!friendships_friend_id_profiles_fkey(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "accepted")
            .execute()
            .value

        // Friendships where user is the receiver — join sender's profile
        let received: [Friendship] = try await supabase.from("friendships")
            .select("*, profiles!friendships_user_id_profiles_fkey(*)")
            .eq("friend_id", value: userId.uuidString)
            .eq("status", value: "accepted")
            .execute()
            .value

        // Deduplicate by friend's profile ID
        var seen = Set<UUID>()
        return (sent + received).filter { friendship in
            let friendId = friendship.friendProfile?.id ?? friendship.id
            return seen.insert(friendId).inserted
        }
    }

    /// Fetches pending friend requests received by the user (join sender's profile).
    func fetchPendingRequests(userId: UUID) async throws -> [Friendship] {
        try await supabase.from("friendships")
            .select("*, profiles!friendships_user_id_profiles_fkey(*)")
            .eq("friend_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    /// Fetches pending friend requests sent by the user (join recipient's profile).
    func fetchSentRequests(userId: UUID) async throws -> [Friendship] {
        try await supabase.from("friendships")
            .select("*, profiles!friendships_friend_id_profiles_fkey(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    // MARK: - Training Partners

    /// Toggles training partner status for a friendship.
    func toggleTrainingPartner(friendshipId: UUID, isPartner: Bool) async throws {
        try await supabase.from("friendships")
            .update(["is_training_partner": isPartner])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    /// Fetches training partners for a user.
    func fetchTrainingPartners(userId: UUID) async throws -> [Friendship] {
        let sent: [Friendship] = try await supabase.from("friendships")
            .select("*, profiles!friendships_friend_id_profiles_fkey(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "accepted")
            .eq("is_training_partner", value: true)
            .execute()
            .value

        let received: [Friendship] = try await supabase.from("friendships")
            .select("*, profiles!friendships_user_id_profiles_fkey(*)")
            .eq("friend_id", value: userId.uuidString)
            .eq("status", value: "accepted")
            .eq("is_training_partner", value: true)
            .execute()
            .value

        return sent + received
    }

    // MARK: - Leaderboard

    /// Fetches the league leaderboard for a given tier.
    func fetchLeaderboard(tier: LeagueTier, limit: Int = 30) async throws -> [SocialProfile] {
        try await supabase.from("profiles")
            .select()
            .eq("league_tier", value: tier.rawValue)
            .order("total_iq", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Updates user's league tier.
    func updateLeagueTier(userId: UUID, tier: LeagueTier) async throws {
        try await supabase.from("profiles")
            .update(["league_tier": tier.rawValue])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
