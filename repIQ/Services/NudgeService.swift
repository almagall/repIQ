import Foundation
import Supabase

/// Generates social-aware coaching nudges that combine intelligence engine data with friend activity.
struct NudgeService: Sendable {

    private let analyticsService = AnalyticsService()

    // MARK: - Generate Nudges

    /// Generates context-aware coaching nudges that incorporate social data.
    func generateNudges(
        userId: UUID,
        friendIds: [UUID],
        friendProfiles: [SocialProfile],
        streakData: StreakData?,
        totalSessions: Int
    ) async throws -> [CoachingNudge] {
        var nudges: [CoachingNudge] = []

        // Fetch friend activity context
        let friendActivity = try await fetchFriendWeeklyActivity(friendIds: friendIds)
        let friendPRCount = try await fetchFriendRecentPRCount(friendIds: friendIds)

        // Fetch user's own weekly data
        let myVolumeTrend = try await analyticsService.fetchWeeklyVolumeTrend(userId: userId, weeks: 2)
        let myRecentPRs = try await analyticsService.fetchRecentPRs(userId: userId, limit: 5)

        // Rule 1: Friends hit PRs — motivate the user
        if friendPRCount > 0 {
            let friendNames = friendProfiles.prefix(3).compactMap(\.displayName).joined(separator: ", ")
            nudges.append(CoachingNudge(
                id: UUID(),
                icon: "star.fill",
                title: "Your Friends Are Crushing It",
                message: "\(friendPRCount) PR\(friendPRCount == 1 ? "" : "s") hit this week by \(friendNames.isEmpty ? "your friends" : friendNames). Your training data suggests you're ready for a push too.",
                accentColor: "warning",
                socialContext: "\(friendPRCount) friend PRs this week",
                actionLabel: "View PRs",
                priority: 1
            ))
        }

        // Rule 2: Friends are training more than you
        let friendAvgWorkouts = friendActivity.isEmpty ? 0 : friendActivity.reduce(0, +) / friendActivity.count
        if let myThisWeek = myVolumeTrend.last, friendAvgWorkouts > myThisWeek.sessionCount && friendAvgWorkouts > 0 {
            nudges.append(CoachingNudge(
                id: UUID(),
                icon: "figure.run",
                title: "Your Circle Is Ahead",
                message: "Your friends averaged \(friendAvgWorkouts) sessions this week. You have \(myThisWeek.sessionCount). Time to catch up!",
                accentColor: "accent",
                socialContext: "Friends avg: \(friendAvgWorkouts) sessions",
                actionLabel: "Start Workout",
                priority: 2
            ))
        }

        // Rule 3: Volume trend — social comparison
        if myVolumeTrend.count >= 2 {
            let current = myVolumeTrend[myVolumeTrend.count - 1].totalVolume
            let previous = myVolumeTrend[myVolumeTrend.count - 2].totalVolume
            if previous > 0 {
                let change = (current - previous) / previous
                if change > 0.15 {
                    nudges.append(CoachingNudge(
                        id: UUID(),
                        icon: "arrow.up.right",
                        title: "Volume Climbing",
                        message: "Your volume is up \(Int(change * 100))% this week. Great progress — keep the momentum but watch your recovery.",
                        accentColor: "success",
                        socialContext: nil,
                        actionLabel: nil,
                        priority: 3
                    ))
                } else if change < -0.20 {
                    nudges.append(CoachingNudge(
                        id: UUID(),
                        icon: "arrow.down.right",
                        title: "Volume Dipped",
                        message: "Your training volume dropped \(Int(abs(change) * 100))% this week. Life happens — a quick session today can get you back on track.",
                        accentColor: "warning",
                        socialContext: nil,
                        actionLabel: "Quick Workout",
                        priority: 2
                    ))
                }
            }
        }

        // Rule 4: Streak motivation
        if let streak = streakData {
            if streak.currentStreak >= 7 && streak.currentStreak < streak.bestStreak {
                nudges.append(CoachingNudge(
                    id: UUID(),
                    icon: "flame.fill",
                    title: "Chasing Your Record",
                    message: "You're on a \(streak.currentStreak)-day streak! Your best is \(streak.bestStreak) days. Keep pushing!",
                    accentColor: "warning",
                    socialContext: nil,
                    actionLabel: nil,
                    priority: 4
                ))
            } else if streak.currentStreak == 0 {
                let activeFriends = friendProfiles.filter { profile in
                    profile.currentStreak > 0
                }
                if !activeFriends.isEmpty {
                    nudges.append(CoachingNudge(
                        id: UUID(),
                        icon: "flame",
                        title: "Start Your Streak",
                        message: "\(activeFriends.count) of your friends have active streaks. Start yours today!",
                        accentColor: "accent",
                        socialContext: "\(activeFriends.count) friends with active streaks",
                        actionLabel: "Start Workout",
                        priority: 3
                    ))
                }
            }
        }

        // Rule 5: Recent PR celebration
        if let recentPR = myRecentPRs.first {
            let daysSince = Calendar.current.dateComponents([.day], from: recentPR.record.achievedAt, to: Date()).day ?? 999
            if daysSince <= 3 {
                nudges.append(CoachingNudge(
                    id: UUID(),
                    icon: "trophy.fill",
                    title: "PR Momentum",
                    message: "You just hit a PR on \(recentPR.exerciseName)! Your training is paying off. Share it with your circle.",
                    accentColor: "warning",
                    socialContext: nil,
                    actionLabel: "Share",
                    priority: 5
                ))
            }
        }

        // Rule 6: Milestone approaching
        let sessionMilestones = [100, 250, 500, 1000]
        for milestone in sessionMilestones {
            let remaining = milestone - totalSessions
            if remaining > 0 && remaining <= 5 {
                nudges.append(CoachingNudge(
                    id: UUID(),
                    icon: "medal.fill",
                    title: "\(remaining) Sessions to Go",
                    message: "You're just \(remaining) workout\(remaining == 1 ? "" : "s") away from your \(milestone)-session milestone!",
                    accentColor: "accent",
                    socialContext: nil,
                    actionLabel: "Let's Go",
                    priority: 1
                ))
                break
            }
        }

        // Sort by priority and return top 3
        nudges.sort { $0.priority < $1.priority }
        return Array(nudges.prefix(3))
    }

    // MARK: - Private Helpers

    /// Fetches workout counts for friends this week.
    private func fetchFriendWeeklyActivity(friendIds: [UUID]) async throws -> [Int] {
        guard !friendIds.isEmpty else { return [] }

        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!

        struct SessionRow: Decodable {
            let user_id: UUID
        }

        let rows: [SessionRow] = try await supabase.from("workout_sessions")
            .select("user_id")
            .in("user_id", values: friendIds.map(\.uuidString))
            .eq("status", value: "completed")
            .gte("completed_at", value: ISO8601DateFormatter().string(from: weekStart))
            .execute()
            .value

        // Count per friend
        var counts: [UUID: Int] = [:]
        for row in rows {
            counts[row.user_id, default: 0] += 1
        }

        return friendIds.map { counts[$0] ?? 0 }
    }

    /// Fetches count of PRs hit by friends in the last 7 days.
    private func fetchFriendRecentPRCount(friendIds: [UUID]) async throws -> Int {
        guard !friendIds.isEmpty else { return 0 }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        struct PRRow: Decodable {
            let id: UUID
        }

        let rows: [PRRow] = try await supabase.from("personal_records")
            .select("id")
            .in("user_id", values: friendIds.map(\.uuidString))
            .gte("achieved_at", value: ISO8601DateFormatter().string(from: weekAgo))
            .execute()
            .value

        return rows.count
    }
}
