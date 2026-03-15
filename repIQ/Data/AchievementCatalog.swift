import Foundation

enum AchievementCatalog {

    /// Evaluates all achievements using milestone progress data and earned badge info.
    static func evaluate(
        data: MilestoneProgressData,
        earnedBadges: [UserBadge],
        friendCount: Int,
        fistBumpsGiven: Int
    ) -> [Achievement] {
        var achievements: [Achievement] = []

        // MARK: - Sessions
        achievements.append(buildAchievement(
            id: "sessions",
            name: "Session Warrior",
            description: "Complete workout sessions",
            icon: "figure.strengthtraining.traditional",
            category: .sessions,
            currentValue: Double(data.totalSessions),
            tiers: [
                ("First Workout", 1),
                ("Dedicated", 10),
                ("Committed", 50),
                ("Centurion", 100),
                ("Iron Regular", 250),
            ]
        ))

        // MARK: - Volume
        achievements.append(buildAchievement(
            id: "volume",
            name: "Volume King",
            description: "Lift total volume in lbs",
            icon: "scalemass.fill",
            category: .volume,
            currentValue: data.totalVolume,
            tiers: [
                ("First Ton", 2_000),
                ("10K Club", 10_000),
                ("50K Club", 50_000),
                ("100K Club", 100_000),
                ("Quarter Million", 250_000),
            ]
        ))

        // MARK: - Streaks
        achievements.append(buildAchievement(
            id: "streaks",
            name: "Streak Master",
            description: "Maintain training streaks",
            icon: "flame.fill",
            category: .streaks,
            currentValue: Double(data.bestStreak),
            tiers: [
                ("Hot Start", 3),
                ("On Fire", 7),
                ("Unstoppable", 14),
                ("Machine", 30),
            ]
        ))

        // MARK: - Personal Records
        achievements.append(buildAchievement(
            id: "prs",
            name: "Record Breaker",
            description: "Achieve personal records",
            icon: "star.fill",
            category: .prs,
            currentValue: Double(data.totalPRs),
            tiers: [
                ("First PR", 1),
                ("PR Hunter", 10),
                ("Record Breaker", 25),
                ("PR Machine", 50),
            ]
        ))

        // MARK: - Exercises
        achievements.append(buildAchievement(
            id: "exercises",
            name: "Explorer",
            description: "Try different exercises",
            icon: "square.grid.3x3",
            category: .exercises,
            currentValue: Double(data.uniqueExercises),
            tiers: [
                ("Explorer", 5),
                ("Versatile", 10),
                ("Well-Rounded", 20),
            ]
        ))

        achievements.append(buildAchievement(
            id: "muscle_groups",
            name: "Complete Athlete",
            description: "Train all muscle groups",
            icon: "checkmark.seal",
            category: .exercises,
            currentValue: Double(data.uniqueMuscleGroups),
            tiers: [
                ("Getting Started", 3),
                ("Balanced", 7),
                ("Complete", 11),
            ]
        ))

        // MARK: - Social
        achievements.append(buildAchievement(
            id: "friends",
            name: "Social Butterfly",
            description: "Build your training network",
            icon: "person.2.fill",
            category: .social,
            currentValue: Double(friendCount),
            tiers: [
                ("First Friend", 1),
                ("Squad", 5),
                ("Crew", 10),
                ("Community", 25),
            ]
        ))

        achievements.append(buildAchievement(
            id: "fist_bumps",
            name: "Encourager",
            description: "Give fist bumps to others",
            icon: "hand.raised.fill",
            category: .social,
            currentValue: Double(fistBumpsGiven),
            tiers: [
                ("Supportive", 5),
                ("Motivator", 25),
                ("Cheerleader", 100),
                ("Inspiration", 500),
            ]
        ))

        return achievements
    }

    // MARK: - Helpers

    private static func buildAchievement(
        id: String,
        name: String,
        description: String,
        icon: String,
        category: AchievementCategory,
        currentValue: Double,
        tiers: [(title: String, threshold: Double)]
    ) -> Achievement {
        let tierLevels = tiers.enumerated().map { index, def in
            let tierEnum: AchievementTier = {
                if tiers.count <= 4 {
                    return AchievementTier(rawValue: index) ?? .diamond
                }
                // For 5+ tiers, map to bronze/silver/gold/diamond based on position
                let ratio = Double(index) / Double(tiers.count - 1)
                if ratio <= 0.25 { return .bronze }
                if ratio <= 0.5 { return .silver }
                if ratio <= 0.75 { return .gold }
                return .diamond
            }()

            return TierLevel(
                tier: tierEnum,
                title: def.title,
                threshold: def.threshold,
                isUnlocked: currentValue >= def.threshold
            )
        }

        return Achievement(
            id: id,
            name: name,
            description: description,
            icon: icon,
            category: category,
            tiers: tierLevels,
            currentValue: currentValue
        )
    }
}
