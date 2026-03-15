import SwiftUI

// MARK: - Achievement Tier

enum AchievementTier: Int, CaseIterable, Comparable, Sendable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case diamond = 3

    static func < (lhs: AchievementTier, rhs: AchievementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C0C0C0")
        case .gold: return RQColors.warning
        case .diamond: return RQColors.info
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "shield"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "shield.fill"
        case .diamond: return "diamond.fill"
        }
    }
}

// MARK: - Achievement Category

enum AchievementCategory: String, CaseIterable, Sendable {
    case sessions
    case volume
    case streaks
    case prs
    case exercises
    case social

    var displayName: String {
        switch self {
        case .sessions: return "Sessions"
        case .volume: return "Volume"
        case .streaks: return "Streaks"
        case .prs: return "PRs"
        case .exercises: return "Exercises"
        case .social: return "Social"
        }
    }

    var color: Color {
        switch self {
        case .sessions: return RQColors.accent
        case .volume: return RQColors.hypertrophy
        case .streaks: return RQColors.warning
        case .prs: return RQColors.success
        case .exercises: return RQColors.info
        case .social: return RQColors.accent
        }
    }
}

// MARK: - Tier Level

struct TierLevel: Identifiable {
    var id: String { "\(tier.rawValue)-\(threshold)" }
    let tier: AchievementTier
    let title: String
    let threshold: Double
    var isUnlocked: Bool
    var unlockedAt: Date?
}

// MARK: - Achievement

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let tiers: [TierLevel]
    let currentValue: Double

    /// The highest tier unlocked, or nil if none.
    var currentTier: AchievementTier? {
        tiers.last(where: { $0.isUnlocked })?.tier
    }

    /// The next tier to unlock, or nil if all unlocked.
    var nextTier: TierLevel? {
        tiers.first(where: { !$0.isUnlocked })
    }

    /// Progress (0.0-1.0) toward the next tier. 1.0 if fully completed.
    var progress: Double {
        guard let next = nextTier else { return 1.0 }
        let previousThreshold = tiers.last(where: { $0.isUnlocked })?.threshold ?? 0
        let range = next.threshold - previousThreshold
        guard range > 0 else { return 0 }
        return min(max((currentValue - previousThreshold) / range, 0), 1.0)
    }

    /// Total number of unlocked tiers.
    var unlockedCount: Int {
        tiers.filter(\.isUnlocked).count
    }

    /// Whether all tiers are unlocked.
    var isCompleted: Bool {
        tiers.allSatisfy(\.isUnlocked)
    }
}
