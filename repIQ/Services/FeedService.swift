import Foundation
import Supabase

/// Manages feed items, reactions (fist bumps), and comments.
struct FeedService: Sendable {

    // MARK: - Feed Items

    /// Creates a feed item for a workout event.
    func createFeedItem(
        userId: UUID,
        sessionId: UUID?,
        itemType: FeedItemType,
        data: FeedItemData
    ) async throws {
        struct CreatePayload: Encodable {
            let user_id: String
            let session_id: String?
            let item_type: String
            let data: FeedItemData
        }

        try await supabase.from("feed_items")
            .insert(CreatePayload(
                user_id: userId.uuidString,
                session_id: sessionId?.uuidString,
                item_type: itemType.rawValue,
                data: data
            ))
            .execute()
    }

    /// Fetches feed items from the user's friends (and self) with profiles, reactions, and comments.
    func fetchFeed(userId: UUID, friendIds: [UUID], limit: Int = 50) async throws -> [FeedItem] {
        let allIds = ([userId] + friendIds).map(\.uuidString)

        // First try full query with nested joins
        if let items: [FeedItem] = try? await supabase.from("feed_items")
            .select("*, profiles(*), feed_reactions(*, profiles(*)), feed_comments(*, profiles(*))")
            .in("user_id", values: allIds)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value {
            return items
        }

        // Fallback: simpler query without nested reaction/comment profiles
        if let items: [FeedItem] = try? await supabase.from("feed_items")
            .select("*, profiles(*), feed_reactions(*), feed_comments(*)")
            .in("user_id", values: allIds)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value {
            return items
        }

        // Final fallback: just feed items with user profile, no reactions/comments
        let items: [FeedItem] = try await supabase.from("feed_items")
            .select("*, profiles(*)")
            .in("user_id", values: allIds)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return items
    }

    /// Fetches feed items for a specific user.
    func fetchUserFeed(userId: UUID, limit: Int = 20) async throws -> [FeedItem] {
        try await supabase.from("feed_items")
            .select("*, profiles(*), feed_reactions(*, profiles(*)), feed_comments(*, profiles(*))")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Reactions (Fist Bumps)

    /// Adds a fist bump reaction to a feed item.
    func addReaction(feedItemId: UUID, userId: UUID) async throws {
        struct CreatePayload: Encodable {
            let feed_item_id: String
            let user_id: String
        }

        try await supabase.from("feed_reactions")
            .insert(CreatePayload(
                feed_item_id: feedItemId.uuidString,
                user_id: userId.uuidString
            ))
            .execute()
    }

    /// Removes a fist bump reaction from a feed item.
    func removeReaction(feedItemId: UUID, userId: UUID) async throws {
        try await supabase.from("feed_reactions")
            .delete()
            .eq("feed_item_id", value: feedItemId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Comments

    /// Adds a comment to a feed item.
    func addComment(feedItemId: UUID, userId: UUID, content: String) async throws {
        struct CreatePayload: Encodable {
            let feed_item_id: String
            let user_id: String
            let content: String
        }

        try await supabase.from("feed_comments")
            .insert(CreatePayload(
                feed_item_id: feedItemId.uuidString,
                user_id: userId.uuidString,
                content: content
            ))
            .execute()
    }

    /// Fetches comments for a feed item.
    func fetchComments(feedItemId: UUID) async throws -> [FeedComment] {
        try await supabase.from("feed_comments")
            .select("*, profiles(*)")
            .eq("feed_item_id", value: feedItemId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }
}
