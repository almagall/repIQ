import Foundation

enum MilestoneCatalog {

    /// Returns all milestone definitions with progress evaluated against the provided data.
    static func evaluate(with data: MilestoneProgressData) -> [MilestoneDefinition] {
        var milestones: [MilestoneDefinition] = []

        // MARK: - Sessions
        let sessionMilestones: [(id: String, title: String, desc: String, icon: String, threshold: Double)] = [
            ("sessions_1", "First Workout", "Complete your first workout session", "figure.strengthtraining.traditional", 1),
            ("sessions_10", "Dedicated", "Complete 10 workout sessions", "flame", 10),
            ("sessions_50", "Committed", "Complete 50 workout sessions", "flame.fill", 50),
            ("sessions_100", "Centurion", "Complete 100 workout sessions", "medal", 100),
            ("sessions_250", "Iron Regular", "Complete 250 workout sessions", "trophy", 250),
        ]
        for m in sessionMilestones {
            let progress = min(Double(data.totalSessions) / m.threshold, 1.0)
            milestones.append(MilestoneDefinition(
                id: m.id,
                category: .sessions,
                title: m.title,
                description: m.desc,
                icon: m.icon,
                threshold: m.threshold,
                isAchieved: Double(data.totalSessions) >= m.threshold,
                progress: progress
            ))
        }

        // MARK: - Volume
        let volumeMilestones: [(id: String, title: String, desc: String, icon: String, threshold: Double)] = [
            ("volume_2k", "First Ton", "Lift 2,000 lbs total volume", "scalemass", 2_000),
            ("volume_10k", "10K Club", "Lift 10,000 lbs total volume", "scalemass.fill", 10_000),
            ("volume_50k", "50K Club", "Lift 50,000 lbs total volume", "dumbbell", 50_000),
            ("volume_100k", "100K Club", "Lift 100,000 lbs total volume", "dumbbell.fill", 100_000),
            ("volume_250k", "Quarter Million", "Lift 250,000 lbs total volume", "trophy.fill", 250_000),
        ]
        for m in volumeMilestones {
            let progress = min(data.totalVolume / m.threshold, 1.0)
            milestones.append(MilestoneDefinition(
                id: m.id,
                category: .volume,
                title: m.title,
                description: m.desc,
                icon: m.icon,
                threshold: m.threshold,
                isAchieved: data.totalVolume >= m.threshold,
                progress: progress
            ))
        }

        // MARK: - Streaks
        let streakMilestones: [(id: String, title: String, desc: String, icon: String, threshold: Double)] = [
            ("streak_3", "Hot Start", "Achieve a 3-day training streak", "bolt", 3),
            ("streak_7", "On Fire", "Achieve a 7-day training streak", "bolt.fill", 7),
            ("streak_14", "Unstoppable", "Achieve a 14-day training streak", "bolt.circle", 14),
            ("streak_30", "Machine", "Achieve a 30-day training streak", "bolt.circle.fill", 30),
        ]
        for m in streakMilestones {
            let best = Double(data.bestStreak)
            let progress = min(best / m.threshold, 1.0)
            milestones.append(MilestoneDefinition(
                id: m.id,
                category: .streaks,
                title: m.title,
                description: m.desc,
                icon: m.icon,
                threshold: m.threshold,
                isAchieved: best >= m.threshold,
                progress: progress
            ))
        }

        // MARK: - Personal Records
        let prMilestones: [(id: String, title: String, desc: String, icon: String, threshold: Double)] = [
            ("prs_1", "First PR", "Achieve your first personal record", "star", 1),
            ("prs_10", "PR Hunter", "Achieve 10 personal records", "star.fill", 10),
            ("prs_25", "Record Breaker", "Achieve 25 personal records", "star.circle", 25),
            ("prs_50", "PR Machine", "Achieve 50 personal records", "star.circle.fill", 50),
        ]
        for m in prMilestones {
            let progress = min(Double(data.totalPRs) / m.threshold, 1.0)
            milestones.append(MilestoneDefinition(
                id: m.id,
                category: .prs,
                title: m.title,
                description: m.desc,
                icon: m.icon,
                threshold: m.threshold,
                isAchieved: Double(data.totalPRs) >= m.threshold,
                progress: progress
            ))
        }

        // MARK: - Exercises
        let exerciseMilestones: [(id: String, title: String, desc: String, icon: String, threshold: Double)] = [
            ("exercises_5", "Explorer", "Try 5 different exercises", "magnifyingglass", 5),
            ("exercises_10", "Versatile", "Try 10 different exercises", "square.grid.3x3", 10),
            ("exercises_all_groups", "Complete", "Train all 11 muscle groups", "checkmark.seal", 11),
        ]
        for (index, m) in exerciseMilestones.enumerated() {
            let value: Double = index < 2 ? Double(data.uniqueExercises) : Double(data.uniqueMuscleGroups)
            let progress = min(value / m.threshold, 1.0)
            milestones.append(MilestoneDefinition(
                id: m.id,
                category: .exercises,
                title: m.title,
                description: m.desc,
                icon: m.icon,
                threshold: m.threshold,
                isAchieved: value >= m.threshold,
                progress: progress
            ))
        }

        return milestones
    }
}
