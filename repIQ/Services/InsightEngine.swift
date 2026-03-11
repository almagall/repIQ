import Foundation
import SwiftUI

struct InsightEngine {

    /// Generates up to 3 actionable insight cards based on the user's data.
    /// Rules are evaluated in priority order; the first 3 that match are returned.
    static func generateInsights(
        volumeTrend: [WeeklyVolumeSummary],
        muscleDistribution: [MuscleGroupVolume],
        streakData: StreakData?,
        recentPRs: [(record: PersonalRecord, exerciseName: String)],
        totalSessions: Int,
        lastWorkoutDate: Date?
    ) -> [InsightCard] {
        var insights: [InsightCard] = []
        let maxInsights = 3

        // Rule 1: Volume dropped >20% week-over-week
        if let drop = volumeDropInsight(volumeTrend: volumeTrend) {
            insights.append(drop)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 2: Volume up >15% week-over-week
        if let gain = volumeGainInsight(volumeTrend: volumeTrend) {
            insights.append(gain)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 3: Muscle imbalance (one group >3x another)
        if let imbalance = muscleImbalanceInsight(distribution: muscleDistribution) {
            insights.append(imbalance)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 4: No workout in 3+ days
        if let inactivity = inactivityInsight(lastWorkoutDate: lastWorkoutDate) {
            insights.append(inactivity)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 5: New PR in last 7 days
        if let prInsight = recentPRInsight(recentPRs: recentPRs) {
            insights.append(prInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 6: Streak is 7+ days
        if let streakInsight = streakInsight(streakData: streakData) {
            insights.append(streakInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 7: High average RPE (not evaluable without per-set RPE data, skip for now)

        // Rule 8: Session milestone
        if let sessionInsight = sessionMilestoneInsight(totalSessions: totalSessions) {
            insights.append(sessionInsight)
        }

        return Array(insights.prefix(maxInsights))
    }

    // MARK: - Individual Rules

    private static func volumeDropInsight(volumeTrend: [WeeklyVolumeSummary]) -> InsightCard? {
        guard volumeTrend.count >= 2 else { return nil }
        let current = volumeTrend[volumeTrend.count - 1]
        let previous = volumeTrend[volumeTrend.count - 2]
        guard previous.totalVolume > 0 else { return nil }

        let changePercent = ((current.totalVolume - previous.totalVolume) / previous.totalVolume) * 100
        guard changePercent < -20 else { return nil }

        return InsightCard(
            icon: "arrow.down.right",
            title: "Volume Dip",
            message: "Your training volume dropped \(Int(abs(changePercent)))% this week. Life happens, but try to get back on track next week.",
            accentColor: RQColors.warning,
            priority: 1
        )
    }

    private static func volumeGainInsight(volumeTrend: [WeeklyVolumeSummary]) -> InsightCard? {
        guard volumeTrend.count >= 2 else { return nil }
        let current = volumeTrend[volumeTrend.count - 1]
        let previous = volumeTrend[volumeTrend.count - 2]
        guard previous.totalVolume > 0 else { return nil }

        let changePercent = ((current.totalVolume - previous.totalVolume) / previous.totalVolume) * 100
        guard changePercent > 15 else { return nil }

        return InsightCard(
            icon: "arrow.up.right",
            title: "Volume Climbing",
            message: "Volume is up \(Int(changePercent))% this week. Great progress! Watch your recovery if you keep increasing.",
            accentColor: RQColors.success,
            priority: 2
        )
    }

    private static func muscleImbalanceInsight(distribution: [MuscleGroupVolume]) -> InsightCard? {
        guard distribution.count >= 2 else { return nil }
        let highest = distribution.first!
        let lowest = distribution.last!
        guard lowest.volume > 0, highest.volume / lowest.volume > 3.0 else { return nil }

        return InsightCard(
            icon: "chart.bar.xaxis",
            title: "Muscle Imbalance",
            message: "Your \(highest.displayName.lowercased()) volume is significantly higher than \(lowest.displayName.lowercased()). Consider adding more \(lowest.displayName.lowercased()) work for balanced development.",
            accentColor: RQColors.info,
            priority: 3
        )
    }

    private static func inactivityInsight(lastWorkoutDate: Date?) -> InsightCard? {
        guard let last = lastWorkoutDate else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        guard daysSince >= 3 else { return nil }

        return InsightCard(
            icon: "clock.badge.exclamationmark",
            title: "Time to Train",
            message: "It's been \(daysSince) days since your last session. A quick workout today can keep your momentum going.",
            accentColor: RQColors.warning,
            priority: 4
        )
    }

    private static func recentPRInsight(recentPRs: [(record: PersonalRecord, exerciseName: String)]) -> InsightCard? {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        guard let recentPR = recentPRs.first(where: { $0.record.achievedAt >= sevenDaysAgo }) else {
            return nil
        }

        let typeName = recentPR.record.recordType.displayName.lowercased()
        return InsightCard(
            icon: "star.fill",
            title: "New PR!",
            message: "You hit a new \(typeName) PR on \(recentPR.exerciseName)! Your training is paying off.",
            accentColor: RQColors.warning,
            priority: 5
        )
    }

    private static func streakInsight(streakData: StreakData?) -> InsightCard? {
        guard let streak = streakData, streak.currentStreak >= 7 else { return nil }

        return InsightCard(
            icon: "flame.fill",
            title: "Streak Going Strong",
            message: "You're on a \(streak.currentStreak)-day streak! Consistency is the #1 factor in long-term progress.",
            accentColor: RQColors.accent,
            priority: 6
        )
    }

    private static func sessionMilestoneInsight(totalSessions: Int) -> InsightCard? {
        // Show for milestones: 10, 25, 50, 100, 150, 200, 250
        let milestones = [10, 25, 50, 100, 150, 200, 250]
        guard milestones.contains(totalSessions) || (totalSessions >= 50 && totalSessions % 50 == 0) else {
            return nil
        }

        return InsightCard(
            icon: "trophy.fill",
            title: "Session Milestone",
            message: "You've completed \(totalSessions) sessions. You're building a serious training foundation.",
            accentColor: RQColors.accent,
            priority: 8
        )
    }
}
