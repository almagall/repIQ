import Foundation
import Supabase

/// Main view model for the Social tab. Orchestrates feed, friends, and gamification data.
@Observable
final class SocialViewModel {
    // MARK: - State
    var feedItems: [FeedItem] = []
    var friends: [Friendship] = []
    var pendingRequests: [Friendship] = []
    var trainingPartners: [Friendship] = []
    var leaderboard: [SocialProfile] = []
    var earnedBadges: [UserBadge] = []
    var allBadges: [Badge] = []
    var activeChallenges: [Challenge] = []
    var userClubs: [Club] = []
    var socialProfile: SocialProfile?

    // Sent requests tracking (for UI state)
    var sentRequestIds: Set<UUID> = []

    // Achievements (unified milestones + badges)
    var achievements: [Achievement] = []
    var celebrationAchievement: Achievement?

    // Phase 4/5 state
    var coachingNudges: [CoachingNudge] = []
    var unreadDigestCount: Int = 0

    var isLoading = false
    var errorMessage: String?

    // MARK: - Services
    private let socialService = SocialService()
    private let feedService = FeedService()
    private let gamificationService = GamificationService()
    private let challengeService = ChallengeService()
    private let nudgeService = NudgeService()
    private let digestService = DigestService()

    // MARK: - Computed

    var currentUserId: UUID? {
        socialProfile?.id
    }

    var friendIds: [UUID] {
        friends.compactMap { friendship in
            if friendship.userId == currentUserId {
                return friendship.friendId
            } else {
                return friendship.userId
            }
        }
    }

    var currentTier: LeagueTier {
        socialProfile?.leagueTier ?? .bronze
    }

    var totalIQ: Int {
        socialProfile?.totalIQ ?? 0
    }

    var currentStreak: Int {
        socialProfile?.currentStreak ?? 0
    }

    var longestStreak: Int {
        socialProfile?.longestStreak ?? 0
    }

    var unearnedBadges: [Badge] {
        let earnedIds = Set(earnedBadges.map(\.badgeId))
        return allBadges.filter { !earnedIds.contains($0.id) }
    }

    /// Badge count for the Social tab (pending requests + unread digests).
    var notificationCount: Int {
        pendingRequests.count
    }

    /// Total unlocked achievement tiers across all achievements.
    var totalUnlockedTiers: Int {
        achievements.reduce(0) { $0 + $1.unlockedCount }
    }

    /// Total possible achievement tiers.
    var totalTiers: Int {
        achievements.reduce(0) { $0 + $1.tiers.count }
    }

    // MARK: - Loading

    /// Loads all social data in parallel.
    func loadSocialData() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        isLoading = true
        errorMessage = nil

        do {
            // Fetch profile separately — don't let it block friends/requests
            socialProfile = try? await socialService.fetchSocialProfile(userId: userId)

            // Fetch friends and pending requests (these are critical)
            async let friendsTask = socialService.fetchFriends(userId: userId)
            async let pendingTask = socialService.fetchPendingRequests(userId: userId)

            friends = (try? await friendsTask) ?? []
            pendingRequests = (try? await pendingTask) ?? []

            // Load sent request IDs so we can show "Sent" in search results
            let sentRequests = (try? await socialService.fetchSentRequests(userId: userId)) ?? []
            sentRequestIds = Set(sentRequests.map(\.friendId))

            // Now fetch remaining data in parallel
            let fIds = friendIds
            let tier = currentTier

            async let feedTask = feedService.fetchFeed(userId: userId, friendIds: fIds)
            async let partnersTask = socialService.fetchTrainingPartners(userId: userId)
            async let leaderboardTask = socialService.fetchLeaderboard(tier: tier)
            async let badgesTask = gamificationService.fetchUserBadges(userId: userId)
            async let allBadgesTask = gamificationService.fetchAllBadges()
            async let challengesTask = challengeService.fetchChallenges(userId: userId)
            async let clubsTask = challengeService.fetchUserClubs(userId: userId)

            feedItems = try await feedTask
            trainingPartners = try await partnersTask
            leaderboard = try await leaderboardTask
            earnedBadges = try await badgesTask
            allBadges = try await allBadgesTask
            activeChallenges = try await challengesTask
            userClubs = try await clubsTask

            // Compute achievements from progress data
            let progressData = try? await gamificationService.fetchMilestoneProgressData(userId: userId)
            if let progressData {
                achievements = AchievementCatalog.evaluate(
                    data: progressData,
                    earnedBadges: earnedBadges,
                    friendCount: friends.count,
                    fistBumpsGiven: 0 // Would need a query; acceptable default
                )
            }

            // Phase 4/5: Load coaching nudges and digest count (non-blocking)
            let streak = StreakData(
                currentStreak: socialProfile?.currentStreak ?? 0,
                bestStreak: socialProfile?.longestStreak ?? 0,
                lastWorkoutDate: socialProfile?.lastWorkoutDate
            )

            // Fetch friend social profiles for nudge context
            var friendSocialProfiles: [SocialProfile] = []
            if !fIds.isEmpty {
                friendSocialProfiles = (try? await supabase.from("profiles")
                    .select()
                    .in("id", values: fIds.map(\.uuidString))
                    .execute()
                    .value) ?? []
            }

            coachingNudges = (try? await nudgeService.generateNudges(
                userId: userId,
                friendIds: fIds,
                friendProfiles: friendSocialProfiles,
                streakData: streak,
                totalSessions: 0
            )) ?? []

            unreadDigestCount = (try? await digestService.unreadCount(userId: userId)) ?? 0

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refreshes only the feed.
    func refreshFeed() async {
        guard let userId = currentUserId else { return }
        do {
            feedItems = try await feedService.fetchFeed(userId: userId, friendIds: friendIds)
        } catch {
            // Silent fail on refresh
        }
    }

    // MARK: - Feed Actions

    /// Toggles fist bump on a feed item.
    func toggleFistBump(feedItemId: UUID) async {
        guard let userId = currentUserId else { return }

        // Find the feed item
        guard let itemIndex = feedItems.firstIndex(where: { $0.id == feedItemId }) else { return }
        let reactions = feedItems[itemIndex].reactions ?? []
        let hasReacted = reactions.contains { $0.userId == userId }

        do {
            if hasReacted {
                try await feedService.removeReaction(feedItemId: feedItemId, userId: userId)
                feedItems[itemIndex].reactions?.removeAll { $0.userId == userId }
            } else {
                try await feedService.addReaction(feedItemId: feedItemId, userId: userId)
                // Optimistic: add a local reaction
                let reaction = FeedReaction(
                    id: UUID(),
                    feedItemId: feedItemId,
                    userId: userId,
                    createdAt: Date()
                )
                if feedItems[itemIndex].reactions != nil {
                    feedItems[itemIndex].reactions?.append(reaction)
                } else {
                    feedItems[itemIndex].reactions = [reaction]
                }
            }
        } catch {
            // Revert on failure — refresh feed
            await refreshFeed()
        }
    }

    /// Adds a comment to a feed item.
    func addComment(feedItemId: UUID, content: String) async {
        guard let userId = currentUserId, !content.isEmpty else { return }

        do {
            try await feedService.addComment(feedItemId: feedItemId, userId: userId, content: content)
            // Optimistic update
            guard let itemIndex = feedItems.firstIndex(where: { $0.id == feedItemId }) else { return }
            let comment = FeedComment(
                id: UUID(),
                feedItemId: feedItemId,
                userId: userId,
                content: content,
                createdAt: Date()
            )
            if feedItems[itemIndex].comments != nil {
                feedItems[itemIndex].comments?.append(comment)
            } else {
                feedItems[itemIndex].comments = [comment]
            }
        } catch {
            // Silent fail
        }
    }

    // MARK: - Friend Actions

    /// Sends a friend request (guards against duplicates).
    func sendFriendRequest(to friendId: UUID) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        // Skip if already friends or already sent
        guard !friendIds.contains(friendId), !sentRequestIds.contains(friendId) else { return }
        // Optimistically show "Sent" immediately
        sentRequestIds.insert(friendId)
        do {
            try await socialService.sendFriendRequest(from: userId, to: friendId)
        } catch {
            // Revert on failure
            sentRequestIds.remove(friendId)
            errorMessage = "Failed to send friend request."
        }
    }

    /// Accepts a friend request.
    func acceptRequest(_ friendship: Friendship) async {
        do {
            try await socialService.acceptFriendRequest(friendshipId: friendship.id)
            pendingRequests.removeAll { $0.id == friendship.id }
            var accepted = friendship
            accepted.status = .accepted
            friends.append(accepted)
        } catch {
            errorMessage = "Failed to accept request."
        }
    }

    /// Declines a friend request.
    func declineRequest(_ friendship: Friendship) async {
        do {
            try await socialService.declineFriendRequest(friendshipId: friendship.id)
            pendingRequests.removeAll { $0.id == friendship.id }
        } catch {
            errorMessage = "Failed to decline request."
        }
    }

    /// Removes a friend.
    func removeFriend(_ friendship: Friendship) async {
        do {
            try await socialService.removeFriendship(friendshipId: friendship.id)
            friends.removeAll { $0.id == friendship.id }
            trainingPartners.removeAll { $0.id == friendship.id }
        } catch {
            errorMessage = "Failed to remove friend."
        }
    }

    /// Toggles training partner status.
    func toggleTrainingPartner(_ friendship: Friendship) async {
        let isCurrentlyPartner = friendship.isTrainingPartner
        do {
            try await socialService.toggleTrainingPartner(
                friendshipId: friendship.id,
                isPartner: !isCurrentlyPartner
            )
            // Update local state
            if let idx = friends.firstIndex(where: { $0.id == friendship.id }) {
                friends[idx].isTrainingPartner = !isCurrentlyPartner
            }
            if isCurrentlyPartner {
                trainingPartners.removeAll { $0.id == friendship.id }
            } else {
                trainingPartners.append(friendship)
            }
        } catch {
            errorMessage = "Failed to update training partner."
        }
    }

    // MARK: - Challenge Actions

    /// Creates a challenge.
    func createChallenge(
        challengedId: UUID,
        type: ChallengeType,
        exerciseId: UUID? = nil,
        days: Int = 7
    ) async {
        guard let userId = currentUserId else { return }
        do {
            try await challengeService.createChallenge(
                challengerId: userId,
                challengedId: challengedId,
                challengeType: type,
                exerciseId: exerciseId,
                durationDays: days
            )
            // Refresh challenges
            activeChallenges = try await challengeService.fetchChallenges(userId: userId)
        } catch {
            errorMessage = "Failed to create challenge."
        }
    }

    /// Accepts a challenge.
    func acceptChallenge(_ challenge: Challenge) async {
        guard let userId = currentUserId else { return }
        do {
            try await challengeService.acceptChallenge(challengeId: challenge.id)
            activeChallenges = try await challengeService.fetchChallenges(userId: userId)
        } catch {
            errorMessage = "Failed to accept challenge."
        }
    }

    /// Declines a challenge.
    func declineChallenge(_ challenge: Challenge) async {
        guard let userId = currentUserId else { return }
        do {
            try await challengeService.declineChallenge(challengeId: challenge.id)
            activeChallenges = try await challengeService.fetchChallenges(userId: userId)
        } catch {
            errorMessage = "Failed to decline challenge."
        }
    }

    // MARK: - Profile

    /// Updates social profile.
    func updateProfile(username: String?, bio: String?, privacyLevel: PrivacyLevel) async {
        guard let userId = currentUserId else { return }
        do {
            try await socialService.updateSocialProfile(
                userId: userId,
                username: username,
                bio: bio,
                privacyLevel: privacyLevel
            )
            socialProfile?.username = username
            socialProfile?.bio = bio
            socialProfile?.privacyLevel = privacyLevel
        } catch {
            errorMessage = "Failed to update profile."
        }
    }

    // MARK: - User Search

    /// Searches for users.
    func searchUsers(query: String) async -> [SocialProfile] {
        // Use auth session directly — don't depend on socialProfile being loaded
        guard let userId = try? await supabase.auth.session.user.id else { return [] }
        do {
            return try await socialService.searchUsers(query: query, currentUserId: userId)
        } catch {
            errorMessage = "Search failed. Please try again."
            return []
        }
    }
}
