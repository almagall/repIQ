import Foundation
import SwiftUI

struct InsightEngine {

    /// Generates up to 3 high-signal, actionable insight cards.
    /// Rules are evaluated in priority order; the first 3 that match are returned.
    static func generateInsights(
        volumeTrend: [WeeklyVolumeSummary],
        muscleDistribution: [MuscleGroupVolume],
        recentPRs: [RecentPREntry],
        totalSessions: Int,
        lastWorkoutDate: Date?,
        averageRPE: Double? = nil,
        topLifts: [TopLiftTrajectory] = [],
        weeklySessionCount: Int = 0
    ) -> [InsightCard] {
        var insights: [InsightCard] = []
        let maxInsights = 3

        // Rule 1: Stalling / regressing on a key lift
        if let stall = stallingInsight(topLifts: topLifts) {
            insights.append(stall)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 2: Recovery alert — average RPE too high
        if let recovery = recoveryInsight(averageRPE: averageRPE) {
            insights.append(recovery)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 3: Volume change vs 4-week baseline
        if let volume = volumeChangeInsight(volumeTrend: volumeTrend) {
            insights.append(volume)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 4: Neglected muscle group
        if let neglected = neglectedMuscleInsight(distribution: muscleDistribution) {
            insights.append(neglected)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 5: No workout in 3+ days
        if let nudge = consistencyNudge(lastWorkoutDate: lastWorkoutDate) {
            insights.append(nudge)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 6: Headroom to push. Deliberately last of the actionable rules —
        // it should only surface when none of the problem rules fired, which is
        // also what makes it a safe default for the hero's coaching line.
        if let ready = readyToProgressInsight(topLifts: topLifts, averageRPE: averageRPE) {
            insights.append(ready)
        }
        guard insights.count < maxInsights else { return insights }

        // Rule 7: New PR celebration
        if let pr = prCelebration(recentPRs: recentPRs) {
            insights.append(pr)
        }

        return Array(insights.prefix(maxInsights))
    }

    // MARK: - Rules

    /// Alerts when a top-tracked lift is stalling or regressing, with actionable advice.
    private static func stallingInsight(topLifts: [TopLiftTrajectory]) -> InsightCard? {
        // Find the highest-priority stalling or regressing lift
        let problematic = topLifts.first(where: {
            $0.velocityStatus == .regressing || $0.velocityStatus == .stalling
        })
        guard let lift = problematic else { return nil }

        let verb = lift.velocityStatus == .regressing ? "declining" : "stalling"
        let dayContext = lift.dayName.map { " on \($0)" } ?? ""

        return InsightCard(
            icon: lift.velocityStatus == .regressing
                ? "arrow.down.right.circle.fill"
                : "arrow.right.circle",
            title: "Strength \(lift.velocityStatus == .regressing ? "Declining" : "Plateau")",
            message: "\(lift.exerciseName)\(dayContext) is \(verb). Consider adding weight, changing rep range, or taking a deload week.",
            accentColor: lift.velocityStatus == .regressing ? RQColors.error : RQColors.warning,
            priority: 1
        )
    }

    /// Surfaces a lift worth pushing when recent effort has been comfortable.
    ///
    /// An average RPE at or below 7 means roughly three reps in reserve across
    /// the fortnight — headroom the progression engine will only exploit one
    /// increment at a time. Naming the fastest-moving lift gives the user a
    /// specific place to spend that headroom rather than generic encouragement.
    private static func readyToProgressInsight(
        topLifts: [TopLiftTrajectory],
        averageRPE: Double?
    ) -> InsightCard? {
        guard let rpe = averageRPE, rpe > 0, rpe <= 7.0 else { return nil }

        // Prefer a lift that's already moving; fall back to any tracked lift so
        // the message still names something concrete.
        let candidate = topLifts.first(where: { $0.velocityStatus.trend == .rising })
            ?? topLifts.first
        guard let lift = candidate else { return nil }

        let dayContext = lift.dayName.map { " on \($0)" } ?? ""
        return InsightCard(
            icon: "arrow.up.right.circle",
            title: "Room to push",
            message: "Effort has averaged RPE \(String(format: "%.1f", rpe)) — you're leaving reps in reserve. \(lift.exerciseName)\(dayContext) is the one to load up next.",
            accentColor: RQColors.success,
            priority: 6
        )
    }

    /// Warns when 14-day average RPE exceeds 8.5, recommending recovery.
    private static func recoveryInsight(averageRPE: Double?) -> InsightCard? {
        guard let rpe = averageRPE, rpe > 8.5 else { return nil }

        return InsightCard(
            icon: "bolt.trianglebadge.exclamationmark",
            title: "High Fatigue",
            message: "Your average RPE has been \(String(format: "%.1f", rpe)) over the past 2 weeks. Consider a lighter session or deload to recover.",
            accentColor: RQColors.error,
            priority: 2
        )
    }

    /// Alerts on significant volume deviation from the 4-week baseline average.
    /// Consolidates both drops and gains into one rule using a stable baseline.
    private static func volumeChangeInsight(volumeTrend: [WeeklyVolumeSummary]) -> InsightCard? {
        // Need at least 5 weeks of data (4 for baseline + 1 current)
        guard volumeTrend.count >= 5 else {
            // Fall back to simple week-over-week if not enough data
            return simpleVolumeChange(volumeTrend: volumeTrend)
        }

        let current = volumeTrend.last!
        // 4-week baseline = average of weeks 2-5 from the end (excluding current)
        let baselineWeeks = volumeTrend.dropLast().suffix(4)
        let baselineAvg = baselineWeeks.map(\.totalVolume).reduce(0, +) / Double(baselineWeeks.count)

        guard baselineAvg > 0 else { return nil }

        let changePercent = ((current.totalVolume - baselineAvg) / baselineAvg) * 100

        if changePercent < -20 {
            return InsightCard(
                icon: "arrow.down.right",
                title: "Volume Drop",
                message: "Volume is down \(Int(abs(changePercent)))% from your 4-week average. If not a planned deload, try to get back on track.",
                accentColor: RQColors.warning,
                priority: 3
            )
        } else if changePercent > 20 {
            return InsightCard(
                icon: "arrow.up.right",
                title: "Volume Spike",
                message: "Volume is up \(Int(changePercent))% over your 4-week average — monitor recovery this week.",
                accentColor: RQColors.success,
                priority: 3
            )
        }

        return nil
    }

    /// Fallback for users with <5 weeks of data — simple week-over-week comparison.
    private static func simpleVolumeChange(volumeTrend: [WeeklyVolumeSummary]) -> InsightCard? {
        guard volumeTrend.count >= 2 else { return nil }
        let current = volumeTrend[volumeTrend.count - 1]
        let previous = volumeTrend[volumeTrend.count - 2]
        guard previous.totalVolume > 0 else { return nil }

        let changePercent = ((current.totalVolume - previous.totalVolume) / previous.totalVolume) * 100

        if changePercent < -25 {
            return InsightCard(
                icon: "arrow.down.right",
                title: "Volume Drop",
                message: "Training volume dropped \(Int(abs(changePercent)))% this week. If not intentional, aim to return to your baseline.",
                accentColor: RQColors.warning,
                priority: 3
            )
        } else if changePercent > 20 {
            return InsightCard(
                icon: "arrow.up.right",
                title: "Volume Spike",
                message: "Volume is up \(Int(changePercent))% this week. Keep increases gradual to avoid overreaching.",
                accentColor: RQColors.success,
                priority: 3
            )
        }

        return nil
    }

    /// Identifies a muscle group receiving minimal training volume relative to others.
    private static func neglectedMuscleInsight(distribution: [MuscleGroupVolume]) -> InsightCard? {
        let totalVolume = distribution.reduce(0.0) { $0 + $1.volume }
        guard totalVolume > 0, distribution.count >= 3 else { return nil }

        // Find muscle groups with <2% of total volume
        let neglected = distribution.filter { ($0.volume / totalVolume) < 0.02 }
        guard let weakest = neglected.first else { return nil }

        return InsightCard(
            icon: "figure.strengthtraining.traditional",
            title: "Neglected Muscle",
            message: "Your \(weakest.displayName.lowercased()) training has been minimal this month. Add 2–3 direct sets per week to maintain balance.",
            accentColor: RQColors.info,
            priority: 4
        )
    }

    /// Nudges the user when they haven't trained in 3+ days.
    private static func consistencyNudge(lastWorkoutDate: Date?) -> InsightCard? {
        guard let last = lastWorkoutDate else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        guard daysSince >= 3 else { return nil }

        return InsightCard(
            icon: "clock.badge.exclamationmark",
            title: "Time to Train",
            message: "It's been \(daysSince) days since your last session. A quick workout gets you back on track.",
            accentColor: RQColors.warning,
            priority: 5
        )
    }

    /// Celebrates a PR achieved in the last 7 days.
    private static func prCelebration(recentPRs: [RecentPREntry]) -> InsightCard? {
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
            priority: 6
        )
    }
}
