import Foundation
import Supabase

@Observable
final class ProgressDashboardViewModel {
    // MARK: - Dashboard Data

    var streakData: StreakData?
    var weeklyVolume: Double = 0
    var weeklySessionCount: Int = 0
    var totalVolume: Double = 0
    var totalPRCount: Int = 0
    var volumeTrend: [WeeklyVolumeSummary] = []
    var recentPRs: [(record: PersonalRecord, exerciseName: String)] = []
    var muscleDistribution: [MuscleGroupVolume] = []
    var fractionalDistribution: [MuscleGroupVolume] = []
    var frequencyData: [(date: Date, count: Int)] = []
    var insights: [InsightCard] = []
    var milestones: [MilestoneDefinition] = []
    var effectiveRepsSummary: [EffectiveRepsSummary] = []
    var averageRPE: Double?

    // Phase Then: new analytics
    var pushPullBalance: PushPullBalance?
    var volumeLandmarks: [VolumeLandmarkData] = []
    var consistencyScore: ConsistencyScore?

    // UI toggle for fractional volume
    var showFractionalVolume: Bool = false

    /// Returns the active muscle distribution based on the fractional toggle.
    var activeMuscleDistribution: [MuscleGroupVolume] {
        showFractionalVolume ? fractionalDistribution : muscleDistribution
    }

    // Computed: milestones sorted for display — achieved (most recent first), then in-progress (highest progress first)
    var displayMilestones: [MilestoneDefinition] {
        let achieved = milestones.filter(\.isAchieved).sorted { $0.threshold > $1.threshold }
        let upcoming = milestones.filter { !$0.isAchieved }.sorted { $0.progress > $1.progress }
        return achieved + upcoming
    }

    /// Next milestones the user is close to achieving (top 3 not-yet-achieved, highest progress first).
    var nextMilestones: [MilestoneDefinition] {
        Array(milestones.filter { !$0.isAchieved }.sorted { $0.progress > $1.progress }.prefix(3))
    }

    /// Recently achieved milestones (for celebration display).
    var achievedMilestones: [MilestoneDefinition] {
        milestones.filter(\.isAchieved).sorted { $0.threshold > $1.threshold }
    }

    // Session history (bottom section)
    var sessions: [WorkoutSession] = []
    var templateNames: [UUID: String] = [:]
    var dayNames: [UUID: String] = [:]

    // Detail view state (used by SessionDetailView)
    var sessionDetail: SessionWithSets?
    var isLoadingDetail = false

    var isLoading = false

    // MARK: - Services

    private let analyticsService = AnalyticsService()
    private let workoutService = WorkoutService()
    private let exerciseService = ExerciseLibraryService()

    // MARK: - Computed

    var volumeDeltaPercent: Double? {
        guard volumeTrend.count >= 2 else { return nil }
        let current = volumeTrend[volumeTrend.count - 1].totalVolume
        let previous = volumeTrend[volumeTrend.count - 2].totalVolume
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    /// Overall effective reps ratio across all muscle groups.
    var overallEffectiveRatio: Double? {
        let totalEffective = effectiveRepsSummary.reduce(0) { $0 + $1.effectiveReps }
        let totalReps = effectiveRepsSummary.reduce(0) { $0 + $1.totalReps }
        guard totalReps > 0 else { return nil }
        return Double(totalEffective) / Double(totalReps)
    }

    // MARK: - Name Helpers

    func templateName(for session: WorkoutSession) -> String? {
        guard let id = session.templateId else { return nil }
        return templateNames[id]
    }

    func dayName(for session: WorkoutSession) -> String? {
        guard let id = session.workoutDayId else { return nil }
        return dayNames[id]
    }

    // MARK: - Loading

    func loadDashboard() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            // Parallel fetch all analytics data
            async let streakTask = analyticsService.fetchCurrentStreak(userId: userId)
            async let volumeTrendTask = analyticsService.fetchWeeklyVolumeTrend(userId: userId, weeks: 8)
            async let muscleTask = analyticsService.fetchMuscleGroupDistribution(userId: userId, days: 30)
            async let fractionalTask = analyticsService.fetchFractionalMuscleDistribution(userId: userId, days: 30)
            async let prTask = analyticsService.fetchRecentPRs(userId: userId, limit: 10)
            async let frequencyTask = analyticsService.fetchTrainingFrequency(userId: userId, weeks: 12)
            async let milestoneTask = analyticsService.fetchMilestoneProgress(userId: userId)
            async let sessionsTask = workoutService.fetchAllSessions(userId: userId)
            async let effectiveRepsTask = analyticsService.fetchEffectiveRepsSummary(userId: userId, days: 30)
            async let rpeTask = analyticsService.fetchAverageRPE(userId: userId, days: 14)
            async let pushPullTask = analyticsService.fetchPushPullBalance(userId: userId, days: 30)
            async let consistencyTask = analyticsService.fetchConsistencyScore(userId: userId, weeks: 8)
            async let landmarkTask = analyticsService.fetchVolumeLandmarkData(userId: userId)

            // Await all
            let fetchedStreak = try await streakTask
            let fetchedTrend = try await volumeTrendTask
            let fetchedMuscle = try await muscleTask
            let fetchedFractional = try await fractionalTask
            let fetchedPRs = try await prTask
            let fetchedFrequency = try await frequencyTask
            let fetchedMilestoneData = try await milestoneTask
            let fetchedSessions = try await sessionsTask
            let fetchedEffectiveReps = try await effectiveRepsTask
            let fetchedRPE = try await rpeTask
            let fetchedPushPull = try await pushPullTask
            let fetchedConsistency = try await consistencyTask
            let fetchedLandmarks = try await landmarkTask

            // Update state
            streakData = fetchedStreak
            volumeTrend = fetchedTrend
            muscleDistribution = fetchedMuscle
            fractionalDistribution = fetchedFractional
            recentPRs = fetchedPRs
            frequencyData = fetchedFrequency
            sessions = fetchedSessions
            milestones = MilestoneCatalog.evaluate(with: fetchedMilestoneData)
            effectiveRepsSummary = fetchedEffectiveReps
            averageRPE = fetchedRPE
            pushPullBalance = fetchedPushPull
            consistencyScore = fetchedConsistency
            volumeLandmarks = fetchedLandmarks

            // Compute overview stats
            totalVolume = fetchedMilestoneData.totalVolume
            totalPRCount = fetchedMilestoneData.totalPRs

            if let currentWeek = fetchedTrend.last {
                weeklyVolume = currentWeek.totalVolume
                weeklySessionCount = currentWeek.sessionCount
            }

            // Generate prescriptive insights with full data
            insights = InsightEngine.generateInsights(
                volumeTrend: fetchedTrend,
                muscleDistribution: fetchedMuscle,
                streakData: fetchedStreak,
                recentPRs: fetchedPRs,
                totalSessions: fetchedSessions.count,
                lastWorkoutDate: fetchedStreak.lastWorkoutDate,
                averageRPE: fetchedRPE,
                effectiveRepsData: fetchedEffectiveReps,
                weeklySessionCount: weeklySessionCount
            )

            // Fetch template/day names for session history
            let templateIds = Array(Set(fetchedSessions.compactMap(\.templateId)))
            let dayIds = Array(Set(fetchedSessions.compactMap(\.workoutDayId)))

            async let templateTask = workoutService.fetchTemplateNames(ids: templateIds)
            async let dayTask = workoutService.fetchWorkoutDayNames(ids: dayIds)

            templateNames = (try? await templateTask) ?? [:]
            dayNames = (try? await dayTask) ?? [:]
        } catch {
            // Silently handle - non-critical
        }
        isLoading = false
    }

    func loadSessionDetail(sessionId: UUID) async {
        isLoadingDetail = true
        do {
            let detail = try await workoutService.fetchSessionDetail(sessionId: sessionId)
            let exerciseIds = Array(Set(detail.sets.map(\.exerciseId)))
            let names = try await exerciseService.fetchExercisesByIds(exerciseIds)

            sessionDetail = SessionWithSets(
                session: detail.session,
                sets: detail.sets,
                exerciseNames: names
            )
        } catch {
            // Silently handle
        }
        isLoadingDetail = false
    }
}
