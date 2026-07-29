import Foundation
import Supabase
import MuscleMap

@Observable
final class ProgressDashboardViewModel {
    // MARK: - Dashboard Data

    var weeklyVolume: Double = 0
    var weeklySessionCount: Int = 0
    var totalVolume: Double = 0
    var totalPRCount: Int = 0
    var totalSessions: Int = 0
    var volumeTrend: [WeeklyVolumeSummary] = []
    var recentPRs: [RecentPREntry] = []
    var muscleDistribution: [MuscleGroupVolume] = []
    var fractionalDistribution: [MuscleGroupVolume] = []
    var frequencyData: [(date: Date, count: Int)] = []
    /// Calendar days within the heatmap window on which the user hit a PR.
    var prDates: Set<Date> = []
    var insights: [InsightCard] = []
    var milestones: [MilestoneDefinition] = []
    var averageRPE: Double?

    // Phase Then: new analytics
    var topLifts: [TopLiftTrajectory] = []
    var monthlyStats: MonthlyStats?
    var lastWorkoutRecap: LastWorkoutRecap?
    var pastMeSnapshot: PastMeSnapshot?

    /// Hero verdict — how many regularly-trained exercises the progression
    /// engine moved up at their last session.
    var progressionVerdict: ProgressionVerdict?

    /// Forward-looking coaching line shown in the hero.
    ///
    /// Prefers an insight that names a specific exercise: "push Bench" is a
    /// thing the user can do on their next session, whereas "volume is down
    /// 28%" is a description they still have to translate into an action. Falls
    /// back to the highest-priority insight when nothing names a lift.
    var heroCoaching: InsightCard? {
        let liftNames = Set(topLifts.map(\.exerciseName))
        let liftSpecific = insights.first { insight in
            liftNames.contains { insight.message.contains($0) }
        }
        return liftSpecific ?? insights.first
    }

    /// Insights excluding the one promoted into the hero, so the same card
    /// never appears twice on the page.
    var secondaryInsights: [InsightCard] {
        guard let promoted = heroCoaching else { return insights }
        return insights.filter { $0.id != promoted.id }
    }

    /// Prior month's Rep Sheet, used to decide whether the recap is news
    /// (promoted under the hero) or already-seen (a footer link).
    var priorMonthRepSheet: RepSheet?

    /// True while last month's Rep Sheet is generated but unread. Unlike the
    /// dashboard banner this isn't date-gated — the Progress tab is where a
    /// user goes looking for a recap, so it stays promoted until opened.
    var hasUnreadRepSheet: Bool {
        guard let sheet = priorMonthRepSheet else { return false }
        return sheet.viewedAt == nil
    }

    /// Body-diagram sex from the user's profile. Defaults to `.male` when the
    /// profile field is missing or "prefer_not_to_say".
    var bodyDiagramGender: BodyGender = .male

    /// Raw profile sex string ("male", "female", "prefer_not_to_say"), used
    /// for strength-standards lookups. Nil when never set.
    var profileSex: String?

    /// User bodyweight in pounds (converted from the canonical kg storage).
    /// Nil when never set; strength-standards rows are hidden in that case.
    var bodyweightLbs: Double?

    // UI toggle for fractional volume
    var showFractionalVolume: Bool = false

    /// When non-nil, the volume chart shows weekly volume contributed only by
    /// exercises whose primary muscle group matches this key. Nil means "all".
    var volumeMuscleFilter: String? = nil
    var isReloadingVolumeTrend = false

    /// Time window that scopes the windowable analytics (volume trend,
    /// muscle distribution, effective reps, PR markers). Defaults to
    /// 12 weeks — the same span the heatmap shows — so the picker doesn't
    /// alter the initial render.
    var selectedTimeWindow: TimeWindow = .twelveWeeks
    var isReloadingWindowedSections = false

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
    private let profileService = ProfileService()
    private let digestService = DigestService()

    // MARK: - Computed

    var volumeDeltaPercent: Double? {
        guard volumeTrend.count >= 2 else { return nil }
        let current = volumeTrend[volumeTrend.count - 1].totalVolume
        let previous = volumeTrend[volumeTrend.count - 2].totalVolume
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    /// 4-week moving average of weekly volume, used as the reference line on the volume chart.
    var volumeBaseline: Double? {
        let validWeeks = volumeTrend.suffix(4).filter { $0.totalVolume > 0 }
        guard !validWeeks.isEmpty else { return nil }
        return validWeeks.reduce(0) { $0 + $1.totalVolume } / Double(validWeeks.count)
    }

    /// One-sentence prescriptive caption for the muscle balance section, keyed
    /// off weekly sets rather than volume share so small muscles aren't flagged
    /// simply for being small.
    var muscleBalanceNarrative: String? {
        let totals = activeMuscleDistribution
        guard !totals.isEmpty else { return nil }
        let totalSets = totals.reduce(0.0) { $0 + $1.setCount }
        guard totalSets > 0 else { return nil }

        let trained = totals.filter { $0.setCount > 0 }
        guard let top = trained.max(by: { $0.setCount < $1.setCount }) else { return nil }

        // A fully untrained group is the strongest signal available.
        if let neglected = totals.first(where: { $0.setCount == 0 }) {
            return "No \(neglected.displayName.lowercased()) work in this window — a couple of direct sets a week holds ground."
        }

        // One group taking more than a third of all sets suggests the split is
        // lopsided rather than that the muscle is well trained.
        let topShare = top.setCount / totalSets
        if topShare > 0.35 {
            return "\(top.displayName) is \(Int(topShare * 100))% of your sets — check the rest aren't sliding."
        }

        if let lowest = trained.min(by: { $0.weeklySets < $1.weeklySets }), lowest.weeklySets < 4 {
            return "\(lowest.displayName) is your lightest at \(lowest.weeklySetsDisplay) sets a week — add a couple if it's a goal."
        }

        return "Balanced spread — keep stacking weeks like this."
    }

    /// An interpreted narrative for the volume trend (replaces the raw percent delta).
    /// A prescriptive coaching caption that combines volume deviation with
    /// recovery (RPE) and recent PR signals to produce actionable guidance.
    /// More specific than a raw deviation message — tells the user what to do.
    var volumeTrendNarrative: String? {
        guard let baseline = volumeBaseline, baseline > 0,
              let current = volumeTrend.last?.totalVolume else { return nil }
        let deviation = ((current - baseline) / baseline) * 100
        let rpe = averageRPE ?? 0
        let hasRecentPRs = recentPRs.contains { pr in
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return pr.record.achievedAt >= sevenDaysAgo
        }
        let isHighFatigue = rpe >= 8.5
        let isLowFatigue = rpe > 0 && rpe <= 7.0

        // Big spike up (>15%)
        if deviation > 15 {
            if isHighFatigue {
                return "Volume up sharply with high RPE — prioritize sleep and recovery this week"
            }
            return "Volume up sharply — keep weekly increases under 10% to avoid overreaching"
        }

        // Modest gain (5-15%)
        if deviation > 5 {
            if hasRecentPRs {
                return "Above baseline and hitting PRs — your training is paying off"
            }
            return "Above 4-week average — solid progressive overload"
        }

        // Steady (-5 to +5%)
        if deviation >= -5 {
            if isLowFatigue {
                return "Steady volume at low effort — consider bumping weight or reps to drive progress"
            }
            if hasRecentPRs {
                return "Holding volume and hitting PRs — quality over quantity working well"
            }
            return "Within sustainable range — keep stacking consistent weeks"
        }

        // Modest dip (-15 to -5%)
        if deviation > -15 {
            if isHighFatigue {
                return "Volume eased back while RPE stays high — smart recovery move"
            }
            if hasRecentPRs {
                return "Volume down slightly but PRs are landing — looks like a peaking week"
            }
            return "Dipping below average — recovery week, or time to add load back?"
        }

        // Significant drop (>15% down)
        if isHighFatigue {
            return "Significant deload — let RPE come down before rebuilding volume"
        }
        return "Significant drop — if not a planned deload, aim to rebuild back to baseline"
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
            async let volumeTrendTask = analyticsService.fetchWeeklyVolumeTrend(
                userId: userId,
                weeks: selectedTimeWindow.weeks
            )
            async let progressionRateTask = analyticsService.fetchProgressionRate(userId: userId)
            async let repSheetTask = digestService.fetchPriorMonthWrapped(userId: userId)
            async let muscleTask = analyticsService.fetchMuscleGroupDistribution(userId: userId, days: 30)
            async let fractionalTask = analyticsService.fetchFractionalMuscleDistribution(userId: userId, days: 30)
            async let prTask = analyticsService.fetchRecentPRs(userId: userId, limit: 10)
            async let frequencyTask = analyticsService.fetchTrainingFrequency(userId: userId, weeks: 12)
            async let milestoneTask = analyticsService.fetchMilestoneProgress(userId: userId)
            async let sessionsTask = workoutService.fetchAllSessions(userId: userId)
            async let rpeTask = analyticsService.fetchAverageRPE(userId: userId, days: 14)
            async let topLiftsTask = analyticsService.fetchTopLiftsTrajectory(userId: userId, limit: 5)
            async let monthlyStatsTask = analyticsService.fetchMonthlyStats(userId: userId)
            async let lastRecapTask = analyticsService.fetchLastWorkoutRecap(userId: userId)
            async let profileTask = profileService.fetchProfile(userId: userId)
            async let prDatesTask = analyticsService.fetchPRDates(userId: userId, days: 84)

            // Progressive assignment: each result is published the moment
            // its task completes, ordered roughly fastest-first so the user
            // sees the hero header (monthly stats, last workout, lifetime
            // totals) as soon as those queries return. Slower aggregates
            // (top lifts, volume landmarks) trickle in afterward.

            if let fetched = try? await monthlyStatsTask { monthlyStats = fetched }
            if let fetched = try? await lastRecapTask { lastWorkoutRecap = fetched }
            if let fetched = try? await progressionRateTask { progressionVerdict = fetched }
            priorMonthRepSheet = (try? await repSheetTask) ?? nil
            let fetchedMilestoneData = try await milestoneTask
            totalVolume = fetchedMilestoneData.totalVolume
            totalPRCount = fetchedMilestoneData.totalPRs
            totalSessions = fetchedMilestoneData.totalSessions
            milestones = MilestoneCatalog.evaluate(with: fetchedMilestoneData)

            let fetchedProfile = try? await profileTask
            bodyDiagramGender = Self.genderForBodyDiagram(profileSex: fetchedProfile?.sex)
            profileSex = fetchedProfile?.sex
            bodyweightLbs = fetchedProfile?.bodyWeightKg.map { $0 * 2.20462 }

            let fetchedTopLifts = (try? await topLiftsTask) ?? []
            topLifts = fetchedTopLifts

            let fetchedSessions = (try? await sessionsTask) ?? []
            sessions = fetchedSessions

            let fetchedTrend = (try? await volumeTrendTask) ?? []
            volumeTrend = fetchedTrend

            let fetchedMuscle = (try? await muscleTask) ?? []
            muscleDistribution = fetchedMuscle

            if let fetched = try? await fractionalTask { fractionalDistribution = fetched }
            if let fetched = try? await prTask { recentPRs = fetched }
            if let fetched = try? await frequencyTask { frequencyData = fetched }
            let fetchedRPE = try? await rpeTask
            averageRPE = fetchedRPE
            prDates = (try? await prDatesTask) ?? []

            // Past-me snapshot on the *most improved* lift rather than simply
            // the most-trained one. With a large exercise library the top lift
            // is an arbitrary pick; the biggest gainer is an actual finding.
            //
            // Candidates are ranked on the three-month snapshot the card
            // actually renders, not on the four-week delta — those windows
            // disagree often enough that ranking by one and displaying the
            // other can label a lift "most improved" while showing a decline.
            pastMeSnapshot = await mostImprovedSnapshot(
                userId: userId,
                candidates: Array(fetchedTopLifts.prefix(4))
            )

            if let currentWeek = fetchedTrend.last {
                weeklyVolume = currentWeek.totalVolume
                weeklySessionCount = currentWeek.sessionCount
            }

            // Generate actionable insights (max 3)
            insights = InsightEngine.generateInsights(
                volumeTrend: fetchedTrend,
                muscleDistribution: fetchedMuscle,
                recentPRs: recentPRs,
                totalSessions: fetchedSessions.count,
                lastWorkoutDate: fetchedSessions.compactMap(\.completedAt).max(),
                averageRPE: fetchedRPE,
                topLifts: fetchedTopLifts,
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

    /// Fetches past-me snapshots for the top candidates in parallel and returns
    /// whichever gained the most over the three-month window. Bounded to a
    /// handful of lifts so this stays a few concurrent reads rather than one
    /// per tracked exercise.
    private func mostImprovedSnapshot(
        userId: UUID,
        candidates: [TopLiftTrajectory]
    ) async -> PastMeSnapshot? {
        guard !candidates.isEmpty else { return nil }

        let snapshots = await withTaskGroup(of: PastMeSnapshot?.self) { group in
            for lift in candidates {
                group.addTask { [analyticsService] in
                    try? await analyticsService.fetchPastMeSnapshot(
                        userId: userId,
                        exerciseId: lift.exerciseId,
                        exerciseName: lift.exerciseName
                    )
                }
            }
            var collected: [PastMeSnapshot] = []
            for await snapshot in group {
                if let snapshot { collected.append(snapshot) }
            }
            return collected
        }

        return snapshots.max(by: { $0.delta < $1.delta })
    }

    /// Maps the profile.sex string to MuscleMap's BodyGender. Anything other than
    /// "female" falls back to `.male` so the diagram still renders for users
    /// who chose "prefer_not_to_say" or never set the field.
    static func genderForBodyDiagram(profileSex: String?) -> BodyGender {
        profileSex?.lowercased() == "female" ? .female : .male
    }

    /// Updates `selectedTimeWindow` and re-fetches every section whose data
    /// is scoped by that window: weekly volume trend, muscle distribution
    /// (direct + fractional), effective reps, and PR markers for the
    /// heatmap.
    func setTimeWindow(_ window: TimeWindow) async {
        guard window != selectedTimeWindow else { return }
        selectedTimeWindow = window
        isReloadingWindowedSections = true
        defer { isReloadingWindowedSections = false }
        guard let userId = try? await supabase.auth.session.user.id else { return }

        async let trendTask = analyticsService.fetchWeeklyVolumeTrend(
            userId: userId,
            weeks: window.weeks,
            muscleGroup: volumeMuscleFilter
        )
        async let muscleTask = analyticsService.fetchMuscleGroupDistribution(userId: userId, days: window.days)
        async let fractionalTask = analyticsService.fetchFractionalMuscleDistribution(userId: userId, days: window.days)
        async let prDatesTask = analyticsService.fetchPRDates(userId: userId, days: window.days)

        let fetchedTrend = (try? await trendTask) ?? []
        let fetchedMuscle = (try? await muscleTask) ?? []
        let fetchedFractional = (try? await fractionalTask) ?? []
        let fetchedPRDates = (try? await prDatesTask) ?? []

        volumeTrend = fetchedTrend
        muscleDistribution = fetchedMuscle
        fractionalDistribution = fetchedFractional
        prDates = fetchedPRDates
    }

    /// Updates `volumeMuscleFilter` and re-fetches the weekly volume trend
    /// filtered to that muscle group (or unfiltered when nil).
    func setVolumeMuscleFilter(_ muscle: String?) async {
        volumeMuscleFilter = muscle
        isReloadingVolumeTrend = true
        defer { isReloadingVolumeTrend = false }
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let fetched = (try? await analyticsService.fetchWeeklyVolumeTrend(
            userId: userId,
            weeks: selectedTimeWindow.weeks,
            muscleGroup: muscle
        )) ?? []
        volumeTrend = fetched
    }

    /// Sessions whose completedAt (or startedAt fallback) lands in the
    /// calendar week containing `weekStart`. Used by the volume chart's
    /// tap-to-drill week detail sheet.
    func sessions(inWeekStartingOn weekStart: Date) -> [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { session in
            let date = session.completedAt ?? session.startedAt
            guard let sessionWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
                return false
            }
            return calendar.isDate(sessionWeekStart, inSameDayAs: weekStart)
        }
    }

    func loadSessionDetail(sessionId: UUID) async {
        isLoadingDetail = true
        do {
            let detail = try await workoutService.fetchSessionDetail(sessionId: sessionId)
            let exerciseIds = Array(Set(detail.sets.map(\.exerciseId)))

            async let exerciseTask = exerciseService.fetchExerciseNamesAndMuscleGroups(exerciseIds)
            async let prsTask = workoutService.fetchSessionPRs(sessionId: sessionId)
            async let modesTask = workoutService.fetchExerciseTrainingModes(
                workoutDayId: detail.session.workoutDayId,
                exerciseIds: exerciseIds
            )

            let (names, muscleGroups) = try await exerciseTask
            let prs = try await prsTask
            let modes = try await modesTask

            sessionDetail = SessionWithSets(
                session: detail.session,
                sets: detail.sets,
                exerciseNames: names,
                exerciseMuscleGroups: muscleGroups,
                exerciseTrainingModes: modes,
                sessionPRs: prs
            )
        } catch {
            // Silently handle
        }
        isLoadingDetail = false
    }
}
