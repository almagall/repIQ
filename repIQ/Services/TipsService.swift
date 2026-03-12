import Foundation
import Supabase

/// Manages crowdsourced exercise tips with upvote/downvote system.
struct TipsService: Sendable {

    // MARK: - Fetch Tips

    /// Fetches tips for a specific exercise, sorted by score (upvotes - downvotes).
    func fetchTips(exerciseId: UUID, userId: UUID, limit: Int = 50) async throws -> [ExerciseTip] {
        var tips: [ExerciseTip] = try await supabase.from("exercise_tips")
            .select("*, profiles(*)")
            .eq("exercise_id", value: exerciseId.uuidString)
            .eq("is_flagged", value: false)
            .order("upvote_count", ascending: false)
            .limit(limit)
            .execute()
            .value

        // Fetch user's votes for these tips
        let tipIds = tips.map(\.id)
        if !tipIds.isEmpty {
            let votes: [TipVote] = try await supabase.from("tip_votes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("tip_id", values: tipIds.map(\.uuidString))
                .execute()
                .value

            let voteMap = Dictionary(uniqueKeysWithValues: votes.map { ($0.tipId, $0) })
            for i in tips.indices {
                tips[i].userVote = voteMap[tips[i].id]
            }
        }

        return tips
    }

    /// Fetches the most popular tips across all exercises (for discovery feed).
    func fetchPopularTips(userId: UUID, limit: Int = 20) async throws -> [ExerciseTip] {
        var tips: [ExerciseTip] = try await supabase.from("exercise_tips")
            .select("*, profiles(*)")
            .eq("is_flagged", value: false)
            .order("upvote_count", ascending: false)
            .limit(limit)
            .execute()
            .value

        // Fetch user votes
        let tipIds = tips.map(\.id)
        if !tipIds.isEmpty {
            let votes: [TipVote] = try await supabase.from("tip_votes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("tip_id", values: tipIds.map(\.uuidString))
                .execute()
                .value

            let voteMap = Dictionary(uniqueKeysWithValues: votes.map { ($0.tipId, $0) })
            for i in tips.indices {
                tips[i].userVote = voteMap[tips[i].id]
            }
        }

        return tips
    }

    // MARK: - Create Tip

    /// Creates a new exercise tip.
    func createTip(
        userId: UUID,
        exerciseId: UUID,
        content: String,
        tipType: TipType
    ) async throws -> ExerciseTip {
        struct Payload: Encodable {
            let user_id: String
            let exercise_id: String
            let content: String
            let tip_type: String
        }

        return try await supabase.from("exercise_tips")
            .insert(Payload(
                user_id: userId.uuidString,
                exercise_id: exerciseId.uuidString,
                content: content,
                tip_type: tipType.rawValue
            ))
            .select("*, profiles(*)")
            .single()
            .execute()
            .value
    }

    /// Deletes a tip owned by the user.
    func deleteTip(tipId: UUID) async throws {
        try await supabase.from("exercise_tips")
            .delete()
            .eq("id", value: tipId.uuidString)
            .execute()
    }

    // MARK: - Voting

    /// Upvotes or downvotes a tip. If user already voted, updates their vote.
    func vote(tipId: UUID, userId: UUID, isUpvote: Bool) async throws {
        // Check existing vote
        let existing: [TipVote] = try await supabase.from("tip_votes")
            .select()
            .eq("tip_id", value: tipId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        if let vote = existing.first {
            if vote.isUpvote == isUpvote {
                // Same vote — remove it (toggle off)
                try await supabase.from("tip_votes")
                    .delete()
                    .eq("id", value: vote.id.uuidString)
                    .execute()

                // Update counts
                try await updateTipCounts(tipId: tipId, deltaUp: isUpvote ? -1 : 0, deltaDown: isUpvote ? 0 : -1)
            } else {
                // Different vote — flip it
                struct UpdatePayload: Encodable { let is_upvote: Bool }
                try await supabase.from("tip_votes")
                    .update(UpdatePayload(is_upvote: isUpvote))
                    .eq("id", value: vote.id.uuidString)
                    .execute()

                // Update counts (remove old, add new)
                try await updateTipCounts(
                    tipId: tipId,
                    deltaUp: isUpvote ? 1 : -1,
                    deltaDown: isUpvote ? -1 : 1
                )
            }
        } else {
            // New vote
            struct InsertPayload: Encodable {
                let tip_id: String
                let user_id: String
                let is_upvote: Bool
            }

            try await supabase.from("tip_votes")
                .insert(InsertPayload(
                    tip_id: tipId.uuidString,
                    user_id: userId.uuidString,
                    is_upvote: isUpvote
                ))
                .execute()

            try await updateTipCounts(tipId: tipId, deltaUp: isUpvote ? 1 : 0, deltaDown: isUpvote ? 0 : 1)
        }
    }

    /// Removes a user's vote from a tip.
    func removeVote(tipId: UUID, userId: UUID) async throws {
        // Find existing vote to know which count to decrement
        let existing: [TipVote] = try await supabase.from("tip_votes")
            .select()
            .eq("tip_id", value: tipId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let vote = existing.first else { return }

        try await supabase.from("tip_votes")
            .delete()
            .eq("id", value: vote.id.uuidString)
            .execute()

        try await updateTipCounts(
            tipId: tipId,
            deltaUp: vote.isUpvote ? -1 : 0,
            deltaDown: vote.isUpvote ? 0 : -1
        )
    }

    /// Flags a tip for moderation.
    func flagTip(tipId: UUID) async throws {
        struct Payload: Encodable { let is_flagged: Bool }
        try await supabase.from("exercise_tips")
            .update(Payload(is_flagged: true))
            .eq("id", value: tipId.uuidString)
            .execute()
    }

    // MARK: - User's Tips

    /// Fetches all tips created by a specific user.
    func fetchUserTips(userId: UUID) async throws -> [ExerciseTip] {
        try await supabase.from("exercise_tips")
            .select("*, profiles(*)")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Private

    private func updateTipCounts(tipId: UUID, deltaUp: Int, deltaDown: Int) async throws {
        // Re-count from source of truth
        struct VoteRow: Decodable { let is_upvote: Bool }
        let votes: [VoteRow] = try await supabase.from("tip_votes")
            .select("is_upvote")
            .eq("tip_id", value: tipId.uuidString)
            .execute()
            .value

        let upCount = votes.filter(\.is_upvote).count
        let downCount = votes.filter { !$0.is_upvote }.count

        struct UpdatePayload: Encodable {
            let upvote_count: Int
            let downvote_count: Int
        }

        try await supabase.from("exercise_tips")
            .update(UpdatePayload(upvote_count: upCount, downvote_count: downCount))
            .eq("id", value: tipId.uuidString)
            .execute()
    }
}
