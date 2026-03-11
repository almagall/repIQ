import Foundation
import SwiftUI

struct InsightEngine {

    /// Generates up to 4 actionable, prescriptive insight cards based on the user's data.
    /// Rules are evaluated in priority order; the first 4 that match are returned.
    static func generateInsights(
        volumeTrend: [WeeklyVolumeSummary],
        muscleDistribution: [MuscleGroupVolume],
        streakData: StreakData?,
        recentPRs: [(record: PersonalRecord, exerciseName: String)],
        totalSessions: Int,
        lastWorkoutDate: Date?,
        averageRPE: Double? = nil,
        effectiveRepsData: [EffectiveRepsSummary] = [],
        weeklySessionCount: Int = 0
    ) -> [InsightCard] {
        var insights: [InsightCard] = []
        let maxInsights = 4

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

        // Rule 3: RPE overreach warning (prescriptive)
        if let rpeInsight = rpeOverreachInsight(averageRPE: averageRPE) {
            insights.append(rpeInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 4: Muscle imbalance (one group >3x another)
        if let imbalance = muscleImbalanceInsight(distribution: muscleDistribution) {
            insights.append(imbalance)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 5: No workout in 3+ days
        if let inactivity = inactivityInsight(lastWorkoutDate: lastWorkoutDate) {
            insights.append(inactivity)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 6: Training efficiency — low effective reps ratio (prescriptive)
        if let efficiencyInsight = trainingEfficiencyInsight(effectiveRepsData: effectiveRepsData) {
            insights.append(efficiencyInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 7: New PR in last 7 days
        if let prInsight = recentPRInsight(recentPRs: recentPRs) {
            insights.append(prInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 8: Frequency optimization (prescriptive)
        if let freqInsight = frequencyInsight(weeklySessionCount: weeklySessionCount, totalSessions: totalSessions) {
            insights.append(freqInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 9: Streak is 7+ days
        if let streakInsight = streakInsight(streakData: streakData) {
            insights.append(streakInsight)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 10: Session milestone
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
            message: "Training volume dropped \(Int(abs(changePercent)))% this week. If intentional (deload), great. Otherwise, aim to return to your baseline next week.",
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
            message: "Volume is up \(Int(changePercent))% this week. Keep the increase under 10% per week to avoid overreaching.",
            accentColor: RQColors.success,
            priority: 2
        )
    }

    /// Prescriptive: warns when average RPE is too high, recommends deload.
    private static func rpeOverreachInsight(averageRPE: Double?) -> InsightCard? {
        guard let rpe = averageRPE, rpe > 9.0 else { return nil }

        return InsightCard(
            icon: "bolt.trianglebadge.exclamationmark",
            title: "High Fatigue",
            message: "Your average effort (RPE \(String(format: "%.1f", rpe))) has been very high. Schedule a deload week — reduce volume by 40–50% to recover and come back stronger.",
            accentColor: RQColors.error,
            priority: 3
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
            message: "Your \(highest.displayName.lowercased()) volume is 3x+ your \(lowest.displayName.lowercased()). Add 2–3 direct \(lowest.displayName.lowercased()) sets per week for balanced development.",
            accentColor: RQColors.info,
            priority: 4
        )
    }

    private static func inactivityInsight(lastWorkoutDate: Date?) -> InsightCard? {
        guard let last = lastWorkoutDate else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        guard daysSince >= 3 else { return nil }

        return InsightCard(
            icon: "clock.badge.exclamationmark",
            title: "Time to Train",
            message: "It's been \(daysSince) days since your last session. Even a short workout keeps your momentum going.",
            accentColor: RQColors.warning,
            priority: 5
        )
    }

    /// Prescriptive: warns when most training is at low RPE (low effective reps ratio).
    private static func trainingEfficiencyInsight(effectiveRepsData: [EffectiveRepsSummary]) -> InsightCard? {
        guard !effectiveRepsData.isEmpty else { return nil }
        let totalEffective = effectiveRepsData.reduce(0) { $0 + $1.effectiveReps }
        let totalReps = effectiveRepsData.reduce(0) { $0 + $1.totalReps }
        guard totalReps > 0 else { return nil }

        let overallRatio = Double(totalEffective) / Double(totalReps)
        guard overallRatio < 0.25 else { return nil }

        let percent = Int(overallRatio * 100)
        return InsightCard(
            icon: "gauge.with.dots.needle.33percent",
            title: "Training Intensity",
            message: "Only \(percent)% of your reps are near failure (effective reps). Training at RPE 7–9 maximizes growth stimulus per set.",
            accentColor: RQColors.info,
            priority: 6
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
            priority: 7
        )
    }

    /// Prescriptive: recommends increasing frequency for better results.
    private static func frequencyInsight(weeklySessionCount: Int, totalSessions: Int) -> InsightCard? {
        // Only suggest after user has at least 4 sessions (not a brand new user)
        guard totalSessions >= 4, weeklySessionCount > 0, weeklySessionCount < 3 else { return nil }

        return InsightCard(
            icon: "calendar.badge.plus",
            title: "Frequency",
            message: "You trained \(weeklySessionCount)x this week. Research shows 3–5 sessions per week optimizes muscle growth and strength gains.",
            accentColor: RQColors.accent,
            priority: 8
        )
    }

    private static func streakInsight(streakData: StreakData?) -> InsightCard? {
        guard let streak = streakData, streak.currentStreak >= 7 else { return nil }

        return InsightCard(
            icon: "flame.fill",
            title: "Streak Going Strong",
            message: "You're on a \(streak.currentStreak)-day streak! Consistency is the #1 factor in long-term progress.",
            accentColor: RQColors.accent,
            priority: 9
        )
    }

    private static func sessionMilestoneInsight(totalSessions: Int) -> InsightCard? {
        let milestones = [10, 25, 50, 100, 150, 200, 250]
        guard milestones.contains(totalSessions) || (totalSessions >= 50 && totalSessions % 50 == 0) else {
            return nil
        }

        return InsightCard(
            icon: "trophy.fill",
            title: "Session Milestone",
            message: "You've completed \(totalSessions) sessions. You're building a serious training foundation.",
            accentColor: RQColors.accent,
            priority: 10
        )
    }
}
