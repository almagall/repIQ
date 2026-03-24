import Foundation

// MARK: - Privacy Level

enum PrivacyLevel: String, Codable, Sendable, CaseIterable {
    case public_ = "public"
    case friendsOnly = "friends_only"
    case private_ = "private"

    var displayName: String {
        switch self {
        case .public_: return "Public"
        case .friendsOnly: return "Friends Only"
        case .private_: return "Private"
        }
    }
}

// MARK: - League Tier

enum LeagueTier: String, Codable, Sendable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case elite

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .elite: return "Elite"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "star.fill"
        case .platinum: return "star.circle.fill"
        case .diamond: return "diamond.fill"
        case .elite: return "crown.fill"
        }
    }

    var colorName: String {
        switch self {
        case .bronze: return "bronze"
        case .silver: return "silver"
        case .gold: return "gold"
        case .platinum: return "platinum"
        case .diamond: return "diamond"
        case .elite: return "elite"
        }
    }
}

// MARK: - Social Profile

struct SocialProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var email: String
    var displayName: String?
    var weightUnit: WeightUnit?
    var restTimerDefault: Int?
    var createdAt: Date
    var updatedAt: Date
    var username: String?
    var bio: String?
    var avatarUrl: String?
    var privacyLevel: PrivacyLevel?
    var leagueTier: LeagueTier?
    var totalIQ: Int?
    var currentStreak: Int?
    var longestStreak: Int?
    var lastWorkoutDate: Date?
    var trainingStyle: String?
    var experienceLevel: String?
    var preferredFrequency: Int?
    var gymName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, bio, username
        case displayName = "display_name"
        case weightUnit = "weight_unit"
        case restTimerDefault = "rest_timer_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case avatarUrl = "avatar_url"
        case privacyLevel = "privacy_level"
        case leagueTier = "league_tier"
        case totalIQ = "total_iq"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastWorkoutDate = "last_workout_date"
        case trainingStyle = "training_style"
        case experienceLevel = "experience_level"
        case preferredFrequency = "preferred_frequency"
        case gymName = "gym_name"
    }
}

// MARK: - Friendship

enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}

struct Friendship: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    var status: FriendshipStatus
    var isTrainingPartner: Bool?
    var partnerStreak: Int?
    let createdAt: Date
    var friendProfile: Profile?

    var safeIsTrainingPartner: Bool { isTrainingPartner ?? false }
    var safePartnerStreak: Int { partnerStreak ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, status
        case userId = "user_id"
        case friendId = "friend_id"
        case isTrainingPartner = "is_training_partner"
        case partnerStreak = "partner_streak"
        case createdAt = "created_at"
        case friendProfile = "profiles"
    }
}

// MARK: - Feed Item Type

enum FeedItemType: String, Codable, Sendable {
    case workoutCompleted = "workout_completed"
    case prAchieved = "pr_achieved"
    case streakMilestone = "streak_milestone"
    case badgeEarned = "badge_earned"
    case leaguePromoted = "league_promoted"
    case challengeWon = "challenge_won"
}

// MARK: - Feed Item Data

struct FeedItemData: Codable, Sendable {
    var duration: Int?
    var totalSets: Int?
    var totalVolume: Double?
    var exerciseCount: Int?
    var prCount: Int?
    var exerciseNames: [String]?
    var streakDays: Int?
    var badgeName: String?
    var leagueTier: String?
    var challengeName: String?

    enum CodingKeys: String, CodingKey {
        case duration
        case totalSets = "total_sets"
        case totalVolume = "total_volume"
        case exerciseCount = "exercise_count"
        case prCount = "pr_count"
        case exerciseNames = "exercise_names"
        case streakDays = "streak_days"
        case badgeName = "badge_name"
        case leagueTier = "league_tier"
        case challengeName = "challenge_name"
    }
}

// MARK: - Feed Item

struct FeedItem: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var sessionId: UUID?
    let itemType: FeedItemType
    var data: FeedItemData
    let createdAt: Date
    var userProfile: Profile?
    var reactions: [FeedReaction]?
    var comments: [FeedComment]?

    enum CodingKeys: String, CodingKey {
        case id, data, reactions, comments
        case userId = "user_id"
        case sessionId = "session_id"
        case itemType = "item_type"
        case createdAt = "created_at"
        case userProfile = "profiles"
    }
}

// MARK: - Feed Reaction

struct FeedReaction: Codable, Identifiable, Sendable {
    let id: UUID
    let feedItemId: UUID
    let userId: UUID
    let createdAt: Date
    var userProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case feedItemId = "feed_item_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case userProfile = "profiles"
    }
}

// MARK: - Feed Comment

struct FeedComment: Codable, Identifiable, Sendable {
    let id: UUID
    let feedItemId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date
    var userProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, content
        case feedItemId = "feed_item_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case userProfile = "profiles"
    }
}

// MARK: - IQ Point Reason

enum IQPointReason: String, Codable, Sendable {
    case setCompleted = "set_completed"
    case targetHit = "target_hit"
    case sessionCompleted = "session_completed"
    case prAchieved = "pr_achieved"
    case streakBonus = "streak_bonus"
    case challengeWon = "challenge_won"
    case weeklyFrequencyBonus = "weekly_frequency_bonus"

    var displayName: String {
        switch self {
        case .setCompleted: return "Set Completed"
        case .targetHit: return "Target Hit"
        case .sessionCompleted: return "Session Completed"
        case .prAchieved: return "PR Achieved"
        case .streakBonus: return "Streak Bonus"
        case .challengeWon: return "Challenge Won"
        case .weeklyFrequencyBonus: return "Weekly Frequency Bonus"
        }
    }

    var pointValue: Int {
        switch self {
        case .setCompleted: return 1
        case .targetHit: return 3
        case .sessionCompleted: return 10
        case .prAchieved: return 25
        case .streakBonus: return 15
        case .challengeWon: return 50
        case .weeklyFrequencyBonus: return 20
        }
    }
}

// MARK: - IQ Point Entry

struct IQPointEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let points: Int
    let reason: IQPointReason
    var referenceId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, points, reason
        case userId = "user_id"
        case referenceId = "reference_id"
        case createdAt = "created_at"
    }
}

// MARK: - Badge Category

enum BadgeCategory: String, Codable, Sendable {
    case volume
    case consistency
    case strength
    case social
    case intelligence
}

// MARK: - Badge

struct Badge: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let category: BadgeCategory
    let requirementType: String
    let requirementValue: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, category
        case requirementType = "requirement_type"
        case requirementValue = "requirement_value"
        case createdAt = "created_at"
    }
}

// MARK: - User Badge

struct UserBadge: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let badgeId: UUID
    let earnedAt: Date
    var badge: Badge?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case badgeId = "badge_id"
        case earnedAt = "earned_at"
        case badge = "badges"
    }
}

// MARK: - Challenge Type

enum ChallengeType: String, Codable, Sendable {
    case iqPoints = "iq_points"
    case prs
    case consistency
    case volumeExercise = "volume_exercise"

    var displayName: String {
        switch self {
        case .iqPoints: return "IQ Points"
        case .prs: return "PRs"
        case .consistency: return "Consistency"
        case .volumeExercise: return "Volume (Exercise)"
        }
    }

    var icon: String {
        switch self {
        case .iqPoints: return "brain.head.profile"
        case .prs: return "trophy.fill"
        case .consistency: return "flame.fill"
        case .volumeExercise: return "dumbbell.fill"
        }
    }
}

// MARK: - Challenge Status

enum ChallengeStatus: String, Codable, Sendable {
    case pending
    case active
    case completed
    case declined
    case expired
}

// MARK: - Challenge

struct Challenge: Codable, Identifiable, Sendable {
    let id: UUID
    let challengerId: UUID
    let challengedId: UUID
    let challengeType: ChallengeType
    var exerciseId: UUID?
    let durationDays: Int
    var startDate: Date?
    var endDate: Date?
    var status: ChallengeStatus
    var challengerScore: Double
    var challengedScore: Double
    var winnerId: UUID?
    let createdAt: Date
    var challengerProfile: Profile?
    var challengedProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, status
        case challengerId = "challenger_id"
        case challengedId = "challenged_id"
        case challengeType = "challenge_type"
        case exerciseId = "exercise_id"
        case durationDays = "duration_days"
        case startDate = "start_date"
        case endDate = "end_date"
        case challengerScore = "challenger_score"
        case challengedScore = "challenged_score"
        case winnerId = "winner_id"
        case createdAt = "created_at"
        case challengerProfile = "challenger_profiles"
        case challengedProfile = "challenged_profiles"
    }
}

// MARK: - Club

struct Club: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String?
    let ownerId: UUID
    var isPublic: Bool
    var memberCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case ownerId = "owner_id"
        case isPublic = "is_public"
        case memberCount = "member_count"
        case createdAt = "created_at"
    }
}

// MARK: - Club Role

enum ClubRole: String, Codable, Sendable {
    case owner
    case admin
    case member
}

// MARK: - Club Member

struct ClubMember: Codable, Identifiable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    var role: ClubRole
    let joinedAt: Date
    var memberProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, role
        case clubId = "club_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case memberProfile = "profiles"
    }
}

// MARK: - Phase 4: Intelligence-Powered Social

// MARK: - Exercise Tip

enum TipType: String, Codable, Sendable, CaseIterable {
    case form
    case variation
    case cue
    case safety
    case progression

    var displayName: String {
        switch self {
        case .form: return "Form"
        case .variation: return "Variation"
        case .cue: return "Cue"
        case .safety: return "Safety"
        case .progression: return "Progression"
        }
    }

    var icon: String {
        switch self {
        case .form: return "figure.strengthtraining.traditional"
        case .variation: return "arrow.triangle.branch"
        case .cue: return "lightbulb.fill"
        case .safety: return "exclamationmark.shield.fill"
        case .progression: return "arrow.up.right"
        }
    }
}

struct ExerciseTip: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let exerciseId: UUID
    var content: String
    var tipType: TipType
    var upvoteCount: Int
    var downvoteCount: Int
    var isFlagged: Bool
    let createdAt: Date
    var userProfile: Profile?
    var userVote: TipVote?

    var score: Int { upvoteCount - downvoteCount }

    enum CodingKeys: String, CodingKey {
        case id, content
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case tipType = "tip_type"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case isFlagged = "is_flagged"
        case createdAt = "created_at"
        case userProfile = "profiles"
        case userVote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        content = try container.decode(String.self, forKey: .content)
        tipType = try container.decode(TipType.self, forKey: .tipType)
        upvoteCount = try container.decode(Int.self, forKey: .upvoteCount)
        downvoteCount = try container.decode(Int.self, forKey: .downvoteCount)
        isFlagged = try container.decode(Bool.self, forKey: .isFlagged)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userProfile = try container.decodeIfPresent(Profile.self, forKey: .userProfile)
        userVote = nil // Loaded separately
    }
}

struct TipVote: Codable, Identifiable, Sendable {
    let id: UUID
    let tipId: UUID
    let userId: UUID
    var isUpvote: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tipId = "tip_id"
        case userId = "user_id"
        case isUpvote = "is_upvote"
        case createdAt = "created_at"
    }
}

// MARK: - Milestone

enum MilestoneType: String, Codable, Sendable, CaseIterable {
    case sessions100 = "sessions_100"
    case sessions250 = "sessions_250"
    case sessions500 = "sessions_500"
    case sessions1000 = "sessions_1000"
    case streak30 = "streak_30"
    case streak90 = "streak_90"
    case streak180 = "streak_180"
    case streak365 = "streak_365"
    case volume100k = "volume_100k"
    case volume500k = "volume_500k"
    case volume1m = "volume_1m"
    case thousandLbClub = "thousand_lb_club"
    case bodyweightBench = "bodyweight_bench"
    case doubleBodyweightSquat = "double_bodyweight_squat"
    case yearAnniversary = "year_anniversary"
    case twoYearAnniversary = "two_year_anniversary"

    var displayName: String {
        switch self {
        case .sessions100: return "Century Club"
        case .sessions250: return "Iron Regular"
        case .sessions500: return "Gym Rat"
        case .sessions1000: return "Living Legend"
        case .streak30: return "30-Day Warrior"
        case .streak90: return "Quarter Beast"
        case .streak180: return "Half-Year Hero"
        case .streak365: return "Year of Iron"
        case .volume100k: return "100K Club"
        case .volume500k: return "Half-Million Lifter"
        case .volume1m: return "Million Pound Club"
        case .thousandLbClub: return "1000 lb Club"
        case .bodyweightBench: return "Bodyweight Bench"
        case .doubleBodyweightSquat: return "Double BW Squat"
        case .yearAnniversary: return "1 Year Strong"
        case .twoYearAnniversary: return "2 Years Strong"
        }
    }

    var icon: String {
        switch self {
        case .sessions100, .sessions250, .sessions500, .sessions1000: return "figure.strengthtraining.traditional"
        case .streak30, .streak90, .streak180, .streak365: return "flame.fill"
        case .volume100k, .volume500k, .volume1m: return "scalemass.fill"
        case .thousandLbClub: return "trophy.fill"
        case .bodyweightBench, .doubleBodyweightSquat: return "star.fill"
        case .yearAnniversary, .twoYearAnniversary: return "calendar.badge.checkmark"
        }
    }

    var description: String {
        switch self {
        case .sessions100: return "Completed 100 workouts"
        case .sessions250: return "Completed 250 workouts"
        case .sessions500: return "Completed 500 workouts"
        case .sessions1000: return "Completed 1,000 workouts"
        case .streak30: return "30-day training streak"
        case .streak90: return "90-day training streak"
        case .streak180: return "180-day training streak"
        case .streak365: return "365-day training streak"
        case .volume100k: return "Lifted 100,000 lbs total"
        case .volume500k: return "Lifted 500,000 lbs total"
        case .volume1m: return "Lifted 1,000,000 lbs total"
        case .thousandLbClub: return "Squat + Bench + Deadlift ≥ 1,000 lbs"
        case .bodyweightBench: return "Benched your bodyweight"
        case .doubleBodyweightSquat: return "Squatted double your bodyweight"
        case .yearAnniversary: return "1 year on repIQ"
        case .twoYearAnniversary: return "2 years on repIQ"
        }
    }
}

struct UserMilestone: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let milestoneType: MilestoneType
    let achievedAt: Date
    var data: MilestoneData?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case milestoneType = "milestone_type"
        case achievedAt = "achieved_at"
        case data
    }
}

struct MilestoneData: Codable, Sendable {
    var totalSessions: Int?
    var totalVolume: Double?
    var streakDays: Int?
    var squat1RM: Double?
    var bench1RM: Double?
    var deadlift1RM: Double?
    var combinedTotal: Double?

    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalVolume = "total_volume"
        case streakDays = "streak_days"
        case squat1RM = "squat_1rm"
        case bench1RM = "bench_1rm"
        case deadlift1RM = "deadlift_1rm"
        case combinedTotal = "combined_total"
    }
}

// MARK: - Weekly Digest

struct WeeklyDigest: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let weekStart: Date
    var friendsTrained: Int
    var totalPRs: Int
    var totalWorkouts: Int
    var leagueChanges: [LeagueChange]?
    var topPerformerId: UUID?
    var topPerformerWorkouts: Int?
    var highlights: [DigestHighlight]?
    var isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weekStart = "week_start"
        case friendsTrained = "friends_trained"
        case totalPRs = "total_prs"
        case totalWorkouts = "total_workouts"
        case leagueChanges = "league_changes"
        case topPerformerId = "top_performer_id"
        case topPerformerWorkouts = "top_performer_workouts"
        case highlights
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

struct LeagueChange: Codable, Sendable {
    let userId: UUID
    let username: String
    let fromTier: LeagueTier
    let toTier: LeagueTier

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case fromTier = "from_tier"
        case toTier = "to_tier"
    }
}

struct DigestHighlight: Codable, Sendable {
    let type: String
    let message: String
    let userId: UUID?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case type, message
        case userId = "user_id"
        case username
    }
}

// MARK: - Monthly Wrapped

struct MonthlyWrapped: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let monthStart: Date
    var totalSessions: Int
    var totalVolume: Double
    var totalSets: Int
    var totalPRs: Int
    var topExerciseName: String?
    var topExerciseVolume: Double?
    var mostConsistentMuscle: String?
    var biggestPRExercise: String?
    var biggestPRValue: Double?
    var biggestPRType: String?
    var percentileRank: Int?
    var avgSessionDuration: Int?
    var longestStreak: Int
    var favoriteDay: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthStart = "month_start"
        case totalSessions = "total_sessions"
        case totalVolume = "total_volume"
        case totalSets = "total_sets"
        case totalPRs = "total_prs"
        case topExerciseName = "top_exercise_name"
        case topExerciseVolume = "top_exercise_volume"
        case mostConsistentMuscle = "most_consistent_muscle"
        case biggestPRExercise = "biggest_pr_exercise"
        case biggestPRValue = "biggest_pr_value"
        case biggestPRType = "biggest_pr_type"
        case percentileRank = "percentile_rank"
        case avgSessionDuration = "avg_session_duration"
        case longestStreak = "longest_streak"
        case favoriteDay = "favorite_day"
        case createdAt = "created_at"
    }
}

// MARK: - Matchmaking

struct MatchmakingResult: Identifiable, Sendable {
    let id: UUID
    let profile: SocialProfile
    let compatibilityScore: Double
    let reasons: [String]
    var sharedExercises: [String]
    var trainingStyleMatch: Bool
    var experienceLevelMatch: Bool
    var frequencyMatch: Bool
}

enum TrainingStyle: String, Codable, Sendable, CaseIterable {
    case hypertrophy
    case strength
    case powerlifting
    case bodybuilding
    case general

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .hypertrophy: return "arrow.up.right.circle.fill"
        case .strength: return "bolt.fill"
        case .powerlifting: return "scalemass.fill"
        case .bodybuilding: return "figure.strengthtraining.traditional"
        case .general: return "star.fill"
        }
    }
}

enum ExperienceLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case elite

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Coaching Nudge

struct CoachingNudge: Identifiable, Sendable {
    let id: UUID
    let icon: String
    let title: String
    let message: String
    let accentColor: String
    let socialContext: String?
    let actionLabel: String?
    let priority: Int
}

// MARK: - Progression Race

struct ProgressionRaceData: Sendable {
    let exerciseName: String
    let exerciseId: UUID
    let mySnapshots: [RaceSnapshot]
    let friendSnapshots: [RaceSnapshot]
    let myCurrentE1RM: Double
    let friendCurrentE1RM: Double
    let myWeeklyGain: Double
    let friendWeeklyGain: Double
}

struct RaceSnapshot: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let estimated1RM: Double
}
