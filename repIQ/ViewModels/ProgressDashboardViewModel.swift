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
    var frequencyData: [(date: Date, count: Int)] = []
    var insights: [InsightCard] = []
    var milestones: [MilestoneDefinition] = []

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
            async let prTask = analyticsService.fetchRecentPRs(userId: userId, limit: 10)
            async let frequencyTask = analyticsService.fetchTrainingFrequency(userId: userId, weeks: 12)
            async let milestoneTask = analyticsService.fetchMilestoneProgress(userId: userId)
            async let sessionsTask = workoutService.fetchAllSessions(userId: userId)

            // Await all
            let fetchedStreak = try await streakTask
            let fetchedTrend = try await volumeTrendTask
            let fetchedMuscle = try await muscleTask
            let fetchedPRs = try await prTask
            let fetchedFrequency = try await frequencyTask
            let fetchedMilestoneData = try await milestoneTask
            let fetchedSessions = try await sessionsTask

            // Update state
            streakData = fetchedStreak
            volumeTrend = fetchedTrend
            muscleDistribution = fetchedMuscle
            recentPRs = fetchedPRs
            frequencyData = fetchedFrequency
            sessions = fetchedSessions
            milestones = MilestoneCatalog.evaluate(with: fetchedMilestoneData)

            // Compute overview stats
            totalVolume = fetchedMilestoneData.totalVolume
            totalPRCount = fetchedMilestoneData.totalPRs

            if let currentWeek = fetchedTrend.last {
                weeklyVolume = currentWeek.totalVolume
                weeklySessionCount = currentWeek.sessionCount
            }

            // Generate insights
            insights = InsightEngine.generateInsights(
                volumeTrend: fetchedTrend,
                muscleDistribution: fetchedMuscle,
                streakData: fetchedStreak,
                recentPRs: fetchedPRs,
                totalSessions: fetchedSessions.count,
                lastWorkoutDate: fetchedStreak.lastWorkoutDate
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
