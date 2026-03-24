import Foundation
import Supabase
import UIKit

@Observable
final class ActiveWorkoutViewModel {
    // MARK: - Workout State
    var exercises: [ExerciseLogEntry] = []
    var currentExerciseIndex: Int = 0
    var sessionId: UUID?
    var startTime: Date = Date()
    var elapsedSeconds: Int = 0
    var isLoading = false
    var errorMessage: String?

    // MARK: - Completion State
    var showFinishConfirmation = false
    var showAbandonConfirmation = false
    var workoutSummary: WorkoutSummaryData?

    // MARK: - Exercise Substitution
    var showExerciseSubstitution = false

    // MARK: - Warmup Suggestion Dismissals
    var dismissedWarmupSuggestions: Set<Int> = [] // exercise indices where user dismissed suggestion

    // MARK: - PR Celebration
    var prCelebration: PRCelebration?

    // MARK: - Deload Suggestion
    var deloadSuggestion: ProgressionService.DeloadSuggestion?

    // MARK: - Rest Timer
    var restTimerRemaining: Int = 0
    var restTimerTarget: Int = 0
    var restTimerActive = false
    var restTimerEnabled = false
    var restTimerDuration: Int = AppConstants.Defaults.restTimerSeconds

    /// Preset durations available for quick selection (in seconds).
    static let timerPresets: [Int] = [30, 60, 90, 120, 150, 180, 240, 300]

    // MARK: - Context
    private(set) var templateName: String = ""
    private(set) var dayName: String = ""
    private(set) var timerStarted = false

    // MARK: - Offline Support
    var isOffline: Bool { !NetworkMonitor.shared.isConnected }
    var hasPendingSets: Bool { OfflineSetQueue.shared.hasPendingSets }
    var pendingSetCount: Int { OfflineSetQueue.shared.pendingCount }

    // MARK: - PR Tracking (for inline celebration)
    /// Current personal records per exercise (keyed by exerciseId), fetched at workout start.
    private var currentPRs: [UUID: [PersonalRecord]] = [:]

    // MARK: - Private
    private let workoutService = WorkoutService()
    private let progressionService = ProgressionService()
    private let exerciseLibraryService = ExerciseLibraryService()
    private let gamificationService = GamificationService()
    private let feedService = FeedService()
    private var timerTask: Task<Void, Never>?
    private var restTimerTask: Task<Void, Never>?
    private var autoSaveTask: Task<Void, Never>?

    deinit {
        timerTask?.cancel()
        restTimerTask?.cancel()
        autoSaveTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Computed

    var elapsedDisplay: String {
        if !timerStarted { return "0:00" }
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var totalCompletedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSetCount }
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    var hasCompletedSets: Bool {
        totalCompletedSets > 0
    }

    var restTimerDisplay: String {
        let minutes = restTimerRemaining / 60
        let seconds = restTimerRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var restTimerProgress: Double {
        guard restTimerTarget > 0 else { return 0 }
        return Double(restTimerTarget - restTimerRemaining) / Double(restTimerTarget)
    }

    var currentExercise: ExerciseLogEntry? {
        exercises[safe: currentExerciseIndex]
    }

    var canGoToPrevious: Bool {
        currentGroupPosition > 0
    }

    var canGoToNext: Bool {
        currentGroupPosition < allGroups.count - 1
    }

    /// Triggers ScrollViewReader to scroll to a specific exercise within the stacked superset view.
    var scrollToExerciseIndex: Int?

    // MARK: - Group Navigation

    /// All exercise indices in the current superset group (or just the current index for solo exercises).
    var currentGroupIndices: [Int] {
        guard let group = exercises[safe: currentExerciseIndex]?.supersetGroup else {
            return [currentExerciseIndex]
        }
        return exercises.enumerated()
            .filter { $0.element.supersetGroup == group }
            .map(\.offset)
    }

    /// Clusters exercises into groups: superset members are grouped together, solo exercises are their own group.
    var allGroups: [[Int]] {
        var groups: [[Int]] = []
        var seen = Set<Int>()
        for (i, exercise) in exercises.enumerated() {
            guard !seen.contains(i) else { continue }
            if let group = exercise.supersetGroup {
                let members = exercises.enumerated()
                    .filter { $0.element.supersetGroup == group }
                    .map(\.offset)
                groups.append(members)
                seen.formUnion(members)
            } else {
                groups.append([i])
                seen.insert(i)
            }
        }
        return groups
    }

    /// The position of the current group in allGroups (for the counter badge).
    var currentGroupPosition: Int {
        allGroups.firstIndex(where: { $0.contains(currentExerciseIndex) }) ?? 0
    }

    /// Current round number for a superset group (1-based).
    func supersetCurrentRound(for groupIndices: [Int]) -> Int {
        let completedCounts = groupIndices.map { idx in
            exercises[safe: idx]?.sets.filter { $0.setType == .working && $0.isCompleted }.count ?? 0
        }
        return min(completedCounts.min() ?? 0, supersetTotalRounds(for: groupIndices) - 1) + 1
    }

    /// Total rounds for a superset group.
    func supersetTotalRounds(for groupIndices: [Int]) -> Int {
        guard let first = groupIndices.first else { return 1 }
        return exercises[safe: first]?.targetSets ?? 3
    }

    // MARK: - Per-Set Target Computation

    /// Computes a mode-aware per-set target by applying the progression decision
    /// to a specific previous set's data.
    ///
    /// Anchors to each set's individual previous weight/reps — this automatically
    /// preserves the user's training style (straight sets, ramping, etc.).
    ///
    /// RPE model differs by training mode:
    /// - **Hypertrophy**: gently ascending RPE across sets (+0.25 per set, capped at 9.0).
    ///   Acknowledges natural fatigue drift without over-prescribing near-failure effort.
    ///   Keeps all sets within the evidence-based RPE 7–9 range (Robinson 2024, Refalo 2023).
    /// - **Strength**: flat RPE across all sets (targetRPE 8.0 / 2 RIR).
    ///   Submaximal effort preserves technique and reduces fatigue (Nuckols, Robinson 2024).
    ///
    /// - Parameters:
    ///   - target: The exercise-level progression target (decision + rep ranges).
    ///   - prev: The previous session's set data for this specific set position.
    ///   - trainingMode: Hypertrophy or strength — drives RPE model.
    ///   - setPosition: 0-indexed position within working sets.
    ///   - equipment: Equipment type for weight increment calculation.
    /// - Returns: A named tuple of (weight, reps, rpe) for this set position.
    static func perSetTarget(
        decision target: ProgressionTarget?,
        previousSet prev: WorkoutSet?,
        trainingMode: TrainingMode,
        setPosition: Int,
        totalSets: Int = 4,
        equipment: String = ""
    ) -> (weight: Double, reps: Int, rpe: Double) {
        // No progression target: use previous data or zeros
        guard let target else {
            let rpe = expectedRPE(
                baseRPE: trainingMode.targetRPE,
                trainingMode: trainingMode,
                setPosition: setPosition,
                totalSets: totalSets
            )
            return (prev?.weight ?? 0, prev?.reps ?? 0, rpe)
        }

        let increment = ProgressionService.weightIncrement(for: equipment)

        switch trainingMode {
        case .hypertrophy:
            // Straight sets: same weight × same rep target all sets
            // RPE naturally drifts up with fatigue
            let rpe = expectedRPE(
                baseRPE: target.targetRPE,
                trainingMode: trainingMode,
                setPosition: setPosition,
                totalSets: totalSets
            )
            return (target.targetWeight, target.targetRepsLow, rpe)

        case .strength:
            // Ascending weight model (Barbell Medicine / 5/3/1 style):
            // All sets use the same rep target. Weight ramps to a top set.
            // Start percentage scales with set count so ramp feels natural:
            //   2 sets: 87% → 100%
            //   3 sets: 82% → 91% → 100%
            //   4 sets: 80% → 87% → 93% → 100%
            //   5 sets: 78% → 84% → 89% → 95% → 100%
            //   6 sets: 77% → 82% → 86% → 91% → 95% → 100%
            let topWeight = target.targetWeight
            let topReps = target.targetRepsLow
            let lastIndex = max(totalSets - 1, 0)

            if totalSets <= 1 {
                return (topWeight, topReps, target.targetRPE)
            }

            // Start percentage decreases as sets increase (more ramp room)
            let startPct: Double
            switch totalSets {
            case 2: startPct = 0.87
            case 3: startPct = 0.82
            case 4: startPct = 0.80
            case 5: startPct = 0.78
            default: startPct = 0.77 // 6+
            }

            let progress = Double(setPosition) / Double(lastIndex)
            let weightPct = startPct + progress * (1.0 - startPct)
            let setWeight = roundToIncrement(topWeight * weightPct, increment)

            // RPE ramps from 6 to target RPE (typically 8), snapped to 0.5 increments
            let rawRPE = 6.0 + progress * (target.targetRPE - 6.0)
            let rpe = (rawRPE * 2).rounded() / 2

            return (setWeight, topReps, rpe)
        }
    }

    /// Computes the expected RPE for a given set position based on training mode.
    /// - Hypertrophy: ascending RPE in 0.5 increments per set, capped at 9.0
    /// - Strength: handled inline in perSetTarget for ramping pattern
    private static func expectedRPE(
        baseRPE: Double,
        trainingMode: TrainingMode,
        setPosition: Int,
        totalSets: Int = 4
    ) -> Double {
        switch trainingMode {
        case .hypertrophy:
            return min(baseRPE + Double(setPosition) * 0.5, 9.0)
        case .strength:
            return baseRPE
        }
    }

    private static func roundToIncrement(_ weight: Double, _ increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded(.down) * increment
    }

    // MARK: - Exercise Navigation

    func goToPreviousExercise() {
        guard canGoToPrevious else { return }
        let prevGroup = allGroups[currentGroupPosition - 1]
        currentExerciseIndex = prevGroup.first ?? currentExerciseIndex
    }

    func goToNextExercise() {
        guard canGoToNext else { return }
        let nextGroup = allGroups[currentGroupPosition + 1]
        currentExerciseIndex = nextGroup.first ?? currentExerciseIndex
    }

    func goToExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        // Navigate to the group that contains this index
        if let group = exercises[index].supersetGroup {
            let groupStart = exercises.enumerated()
                .filter { $0.element.supersetGroup == group }
                .map(\.offset)
                .first ?? index
            currentExerciseIndex = groupStart
            scrollToExerciseIndex = index
        } else {
            currentExerciseIndex = index
        }
    }

    // MARK: - Lifecycle

    func startWorkout(template: Template, day: WorkoutDay, date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        templateName = template.name
        dayName = day.name

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                errorMessage = "Not authenticated."
                isLoading = false
                return
            }

            // 1. Create session in Supabase with selected date
            let session = try await workoutService.createSession(
                userId: userId,
                templateId: template.id,
                workoutDayId: day.id,
                startDate: date
            )
            sessionId = session.id
            startTime = session.startedAt

            // 2. Get exercise IDs for batch fetch
            let dayExercises = day.exercises ?? []
            let exerciseIds = dayExercises.map(\.exerciseId)

            // 3. Fetch previous session data and progression targets in parallel
            async let previousDataTask = workoutService.fetchPreviousSetsForExercises(
                exerciseIds: exerciseIds,
                userId: userId
            )
            async let targetsTask = progressionService.fetchLatestTargets(
                userId: userId,
                exerciseIds: exerciseIds
            )

            let previousData = try await previousDataTask
            let targets = (try? await targetsTask) ?? [:]

            // 3b. Fetch current PRs for inline PR detection
            for exerciseId in exerciseIds {
                if let prs = try? await progressionService.fetchCurrentPRs(userId: userId, exerciseId: exerciseId) {
                    currentPRs[exerciseId] = prs
                }
            }

            // 4. Build ExerciseLogEntry array
            exercises = dayExercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map { dayExercise in
                let prevSets = previousData[dayExercise.exerciseId] ?? []
                let target = targets[dayExercise.exerciseId]
                let restSeconds = dayExercise.restSecondsOverride
                    ?? dayExercise.exercise?.defaultRestSeconds
                    ?? AppConstants.Defaults.restTimerSeconds

                // Pre-fill sets: compute per-set targets from progression decision + previous set data
                let equipmentType = dayExercise.exercise?.equipment ?? ""
                var sets: [SetEntry] = []
                for i in 1...dayExercise.targetSets {
                    let prev = prevSets[safe: i - 1]
                    let (w, r, _) = Self.perSetTarget(
                        decision: target,
                        previousSet: prev,
                        trainingMode: dayExercise.trainingMode,
                        setPosition: i - 1,
                        totalSets: dayExercise.targetSets,
                        equipment: equipmentType
                    )
                    sets.append(SetEntry(
                        setNumber: i,
                        setType: .working,
                        weight: w,
                        reps: r
                    ))
                }

                return ExerciseLogEntry(
                    id: dayExercise.id,
                    exerciseId: dayExercise.exerciseId,
                    exerciseName: dayExercise.exercise?.name ?? "Unknown Exercise",
                    muscleGroup: dayExercise.exercise?.muscleGroup ?? "",
                    equipment: dayExercise.exercise?.equipment ?? "",
                    trainingMode: dayExercise.trainingMode,
                    targetSets: dayExercise.targetSets,
                    restSeconds: restSeconds,
                    sortOrder: dayExercise.sortOrder,
                    sets: sets,
                    previousSets: prevSets.isEmpty ? [] : [prevSets],
                    progressionTarget: target,
                    repCap: dayExercise.repCap,
                    supersetGroup: dayExercise.supersetGroup
                )
            }

            // 5. Keep screen awake during workout
            UIApplication.shared.isIdleTimerDisabled = true

            // 6. Start periodic auto-save for crash recovery
            startAutoSave()

            // 7. Check if proactive deload should be suggested
            if let templateId = template.id as UUID? {
                deloadSuggestion = try? await progressionService.shouldSuggestDeload(
                    userId: userId,
                    templateId: templateId
                )
            }

        } catch {
            errorMessage = "Failed to start workout: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Deload Suggestion Actions

    func dismissDeloadSuggestion() {
        deloadSuggestion = nil
    }

    func applyDeloadToAllExercises() {
        for i in exercises.indices {
            guard let target = exercises[i].progressionTarget else { continue }
            let deloadWeight = (target.targetWeight * 0.9).rounded()
            let increment = ProgressionService.weightIncrement(for: exercises[i].equipment)
            let roundedWeight = increment > 0
                ? (deloadWeight / increment).rounded(.down) * increment
                : deloadWeight

            exercises[i].progressionTarget = ProgressionTarget(
                exerciseId: target.exerciseId,
                trainingMode: target.trainingMode,
                targetWeight: roundedWeight,
                targetRepsLow: target.targetRepsLow,
                targetRepsHigh: target.targetRepsHigh,
                targetRPE: target.targetRPE,
                decision: .deload,
                reasoning: "Proactive deload — reducing weight 10% for recovery.",
                previousWeight: target.previousWeight,
                previousReps: target.previousReps,
                previousRPE: target.previousRPE,
                estimatedOneRM: target.estimatedOneRM
            )

            // Update pre-filled set values to match deload targets
            for j in exercises[i].sets.indices where !exercises[i].sets[j].isCompleted {
                let prev = exercises[i].previousSets.first?[safe: j]
                let (w, r, _) = Self.perSetTarget(
                    decision: exercises[i].progressionTarget,
                    previousSet: prev,
                    trainingMode: exercises[i].trainingMode,
                    setPosition: j,
                    equipment: exercises[i].equipment
                )
                exercises[i].sets[j].weight = w
                exercises[i].sets[j].reps = r
            }
        }
        deloadSuggestion = nil
    }

    func completeWorkout() async {
        guard let sessionId else { return }
        isLoading = true

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                errorMessage = "Not authenticated."
                isLoading = false
                return
            }

            let duration = Int(Date().timeIntervalSince(startTime))
            try await workoutService.completeSession(
                sessionId: sessionId,
                durationSeconds: duration
            )

            // Build exercise summaries
            let exerciseSummaries: [WorkoutSummaryData.ExerciseSummary] = exercises.compactMap { exercise in
                let completed = exercise.sets.filter(\.isCompleted)
                guard !completed.isEmpty else { return nil }
                let topSet = completed.max(by: { $0.weight < $1.weight })
                return WorkoutSummaryData.ExerciseSummary(
                    id: exercise.exerciseId,
                    name: exercise.exerciseName,
                    muscleGroup: exercise.muscleGroup,
                    trainingMode: exercise.trainingMode,
                    setsCompleted: completed.count,
                    totalVolume: exercise.totalVolume,
                    topWeight: topSet?.weight ?? 0,
                    topReps: topSet?.reps ?? 0
                )
            }

            // Run PR detection and progression calculations
            var allNewPRs: [PRSummary] = []
            var allDecisions: [ProgressionSummary] = []

            for exercise in exercises {
                let completedWorking = exercise.sets.filter { $0.isCompleted && $0.setType == .working }
                guard !completedWorking.isEmpty else { continue }

                // Convert SetEntry to WorkoutSet for the service
                let workoutSets = completedWorking.map { set in
                    WorkoutSet(
                        id: set.savedSetId ?? UUID(),
                        sessionId: sessionId,
                        exerciseId: exercise.exerciseId,
                        setNumber: set.setNumber,
                        setType: set.setType,
                        weight: set.weight,
                        reps: set.reps,
                        rpe: set.rpe,
                        isPR: false,
                        notes: nil,
                        completedAt: Date(),
                        createdAt: Date()
                    )
                }

                // Detect PRs
                if let newPRs = try? await progressionService.detectPRs(
                    exerciseId: exercise.exerciseId,
                    userId: userId,
                    sessionId: sessionId,
                    completedSets: workoutSets
                ) {
                    for pr in newPRs {
                        allNewPRs.append(PRSummary(
                            exerciseName: exercise.exerciseName,
                            recordType: pr.recordType,
                            value: pr.value,
                            previousValue: nil
                        ))
                    }
                }

                // Calculate next targets
                // The current session is already marked completed, so
                // fetchPreviousSetsForExercise includes it automatically.
                let recentSessions = (try? await workoutService.fetchPreviousSetsForExercise(
                    exerciseId: exercise.exerciseId,
                    userId: userId,
                    limit: 3
                )) ?? []

                if let target = progressionService.calculateTarget(
                    exerciseId: exercise.exerciseId,
                    trainingMode: exercise.trainingMode,
                    equipment: exercise.equipment,
                    recentSessions: recentSessions,
                    repCap: exercise.repCap
                ) {
                    try? await progressionService.saveTarget(target, userId: userId)

                    allDecisions.append(ProgressionSummary(
                        exerciseName: exercise.exerciseName,
                        decision: target.decision,
                        targetWeight: target.targetWeight,
                        targetReps: target.targetRepRangeDisplay,
                        reasoning: target.reasoning
                    ))
                }
            }

            // --- Gamification ---
            // Update streak (no freezes — streak breaks if you don't train)
            let streakResult = (try? await gamificationService.updateStreak(userId: userId))
                ?? (currentStreak: 0, longestStreak: 0)

            // Award IQ points for actual training actions
            let iqEarned = (try? await gamificationService.awardWorkoutRewards(
                userId: userId,
                sessionId: sessionId,
                completedSets: totalCompletedSets,
                targetsHit: 0, // TODO: track targets hit during workout
                newPRCount: allNewPRs.count,
                currentStreak: streakResult.currentStreak
            )) ?? 0

            // Evaluate badges
            let newBadges = (try? await gamificationService.evaluateBadges(
                userId: userId,
                totalSessions: 0, // Let the service query if needed
                totalSets: totalCompletedSets,
                totalVolume: totalVolume,
                currentStreak: streakResult.currentStreak,
                longestStreak: streakResult.longestStreak,
                totalPRs: allNewPRs.count,
                friendsCount: 0,
                fistBumpsGiven: 0
            )) ?? []

            // Create feed item for workout completion
            let feedData = FeedItemData(
                duration: duration,
                totalSets: totalCompletedSets,
                totalVolume: totalVolume,
                exerciseCount: exerciseSummaries.count,
                prCount: allNewPRs.isEmpty ? nil : allNewPRs.count,
                exerciseNames: exerciseSummaries.map(\.name),
                workoutDayName: dayName.isEmpty ? nil : dayName
            )
            try? await feedService.createFeedItem(
                userId: userId,
                sessionId: sessionId,
                itemType: .workoutCompleted,
                data: feedData
            )

            // Create PR feed items
            if !allNewPRs.isEmpty {
                let prFeedData = FeedItemData(
                    prCount: allNewPRs.count,
                    prDetails: allNewPRs.map { pr in
                        FeedPRDetail(
                            exerciseName: pr.exerciseName,
                            recordType: pr.recordType.rawValue,
                            value: pr.value
                        )
                    }
                )
                try? await feedService.createFeedItem(
                    userId: userId,
                    sessionId: sessionId,
                    itemType: .prAchieved,
                    data: prFeedData
                )
            }

            // Create streak milestone feed items (at 7, 14, 30, 60, 90, 180, 365)
            let streakMilestones = [7, 14, 30, 60, 90, 180, 365]
            if streakMilestones.contains(streakResult.currentStreak) {
                let streakData = FeedItemData(streakDays: streakResult.currentStreak)
                try? await feedService.createFeedItem(
                    userId: userId,
                    sessionId: nil,
                    itemType: .streakMilestone,
                    data: streakData
                )
            }

            // Create badge feed items
            for badge in newBadges {
                let badgeData = FeedItemData(badgeName: badge.name)
                try? await feedService.createFeedItem(
                    userId: userId,
                    sessionId: nil,
                    itemType: .badgeEarned,
                    data: badgeData
                )
            }

            // Evaluate milestones (Phase 4)
            let matchmakingService = MatchmakingService()
            let newMilestones = try? await matchmakingService.evaluateMilestones(
                userId: userId,
                totalSessions: 0, // Service queries actual count
                totalVolume: totalVolume,
                currentStreak: streakResult.currentStreak,
                longestStreak: streakResult.longestStreak,
                accountCreatedAt: nil
            )

            // Create feed items for new milestones (celebrations visible to friends)
            if let milestones = newMilestones {
                for milestone in milestones {
                    let milestoneData = FeedItemData(badgeName: milestone.milestoneType.displayName)
                    try? await feedService.createFeedItem(
                        userId: userId,
                        sessionId: nil,
                        itemType: .badgeEarned,
                        data: milestoneData
                    )
                }
            }

            // Build summary with PR, progression, and gamification data
            var summary = WorkoutSummaryData(
                duration: duration,
                totalSets: totalCompletedSets,
                totalVolume: totalVolume,
                exerciseSummaries: exerciseSummaries,
                newPRs: allNewPRs,
                progressionDecisions: allDecisions,
                iqPointsEarned: iqEarned,
                currentStreak: streakResult.currentStreak,
                longestStreak: streakResult.longestStreak,
                newBadges: newBadges
            )
            summary.workoutName = dayName.isEmpty ? templateName : "\(templateName) — \(dayName)"
            summary.dayName = dayName
            summary.workoutDate = startTime
            workoutSummary = summary

            timerTask?.cancel()
            autoSaveTask?.cancel()
            cancelRestTimer()
            WorkoutAutoSave.clear()
            UIApplication.shared.isIdleTimerDisabled = false

            // Sync any offline sets that were queued
            await syncOfflineSets()

        } catch {
            errorMessage = "Failed to complete workout: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func abandonWorkout() async {
        guard let sessionId else { return }

        do {
            try await workoutService.abandonSession(sessionId: sessionId)
        } catch {
            // Best-effort, still dismiss
        }

        timerTask?.cancel()
        autoSaveTask?.cancel()
        cancelRestTimer()
        WorkoutAutoSave.clear()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Set Management

    func completeSet(exerciseIndex: Int, setIndex: Int) async {
        guard let sessionId,
              exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let set = exercises[exerciseIndex].sets[setIndex]
        guard !set.isCompleted, !set.isSaving else { return }
        guard set.weight > 0, set.reps > 0 else {
            errorMessage = "Enter weight and reps before completing."
            return
        }

        exercises[exerciseIndex].sets[setIndex].isSaving = true
        errorMessage = nil

        do {
            let savedSet = try await workoutService.saveSet(
                sessionId: sessionId,
                exerciseId: exercises[exerciseIndex].exerciseId,
                setNumber: set.setNumber,
                setType: set.setType,
                weight: set.weight,
                reps: set.reps,
                rpe: set.rpe
            )

            exercises[exerciseIndex].sets[setIndex].savedSetId = savedSet.id
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
            exercises[exerciseIndex].sets[setIndex].isSaving = false
        } catch {
            // Offline fallback: queue the set for later sync
            let pending = PendingSet(
                sessionId: sessionId,
                exerciseId: exercises[exerciseIndex].exerciseId,
                setNumber: set.setNumber,
                setType: set.setType,
                weight: set.weight,
                reps: set.reps,
                rpe: set.rpe
            )
            OfflineSetQueue.shared.enqueue(pending)

            // Still mark as completed locally so the user can continue
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
            exercises[exerciseIndex].sets[setIndex].isSaving = false
        }

        // Check for inline PRs (weight PR and rep PR)
        let completedSet = exercises[exerciseIndex].sets[setIndex]
        if completedSet.isCompleted && completedSet.setType == .working {
            let exerciseId = exercises[exerciseIndex].exerciseId
            let exerciseName = exercises[exerciseIndex].exerciseName
            let prs = currentPRs[exerciseId] ?? []

            // Weight PR: heaviest weight ever lifted
            let weightPR = prs.first(where: { $0.recordType == .weight })
            let currentWeightPR = weightPR?.value ?? 0

            if completedSet.weight > currentWeightPR && completedSet.weight > 0 {
                // Clear previous weight PR badge from earlier sets of the same exercise
                for i in 0..<exercises[exerciseIndex].sets.count where i != setIndex {
                    if exercises[exerciseIndex].sets[i].prType == .weight {
                        exercises[exerciseIndex].sets[i].prType = nil
                    }
                }
                exercises[exerciseIndex].sets[setIndex].prType = .weight
                let weightDelta = completedSet.weight - currentWeightPR
                let pctImprovement = currentWeightPR > 0 ? (weightDelta / currentWeightPR) * 100 : nil
                // Epley formula: 1RM = weight × (1 + reps / 30)
                let est1RM = completedSet.reps > 1
                    ? completedSet.weight * (1.0 + Double(completedSet.reps) / 30.0)
                    : completedSet.weight
                prCelebration = PRCelebration(
                    exerciseName: exerciseName,
                    prType: .weight,
                    newValue: "\(formatWeightForPR(completedSet.weight)) lbs × \(completedSet.reps)",
                    previousValue: currentWeightPR > 0
                        ? "\(formatWeightForPR(currentWeightPR)) lbs × \(weightPR?.repsAtWeight ?? 0)"
                        : "None",
                    previousDate: weightPR?.achievedAt,
                    delta: currentWeightPR > 0 ? "+\(formatWeightForPR(weightDelta)) lbs" : nil,
                    percentImprovement: pctImprovement,
                    estimated1RM: est1RM
                )
                // Update tracked PR so subsequent sets compare against the new best
                if var exercisePRs = currentPRs[exerciseId],
                   let prIndex = exercisePRs.firstIndex(where: { $0.recordType == .weight }) {
                    exercisePRs[prIndex] = PersonalRecord(
                        id: exercisePRs[prIndex].id, userId: exercisePRs[prIndex].userId,
                        exerciseId: exerciseId, recordType: .weight,
                        value: completedSet.weight, repsAtWeight: completedSet.reps,
                        sessionId: sessionId, achievedAt: Date(), createdAt: Date()
                    )
                    currentPRs[exerciseId] = exercisePRs
                }
            } else {
                // Rep PR: most reps ever at this exact weight
                let repPR = prs.first(where: { $0.recordType == .reps && $0.value == completedSet.weight })
                let currentRepPR = Int(repPR?.repsAtWeight ?? 0)

                if completedSet.reps > currentRepPR && completedSet.reps > 0 && completedSet.weight > 0 {
                    // Clear previous rep PR badge at this weight from earlier sets
                    for i in 0..<exercises[exerciseIndex].sets.count where i != setIndex {
                        if exercises[exerciseIndex].sets[i].prType == .reps
                            && exercises[exerciseIndex].sets[i].weight == completedSet.weight {
                            exercises[exerciseIndex].sets[i].prType = nil
                        }
                    }
                    exercises[exerciseIndex].sets[setIndex].prType = .reps
                    let repDelta = completedSet.reps - currentRepPR
                    let pctImprovement = currentRepPR > 0 ? (Double(repDelta) / Double(currentRepPR)) * 100 : nil
                    prCelebration = PRCelebration(
                        exerciseName: exerciseName,
                        prType: .reps,
                        newValue: "\(formatWeightForPR(completedSet.weight)) lbs × \(completedSet.reps)",
                        previousValue: currentRepPR > 0
                            ? "\(formatWeightForPR(completedSet.weight)) lbs × \(currentRepPR)"
                            : "None",
                        previousDate: repPR?.achievedAt,
                        delta: currentRepPR > 0 ? "+\(repDelta) reps" : nil,
                        percentImprovement: pctImprovement,
                        estimated1RM: nil
                    )
                    // Update tracked rep PR
                    if var exercisePRs = currentPRs[exerciseId],
                       let prIndex = exercisePRs.firstIndex(where: { $0.recordType == .reps && $0.value == completedSet.weight }) {
                        exercisePRs[prIndex] = PersonalRecord(
                            id: exercisePRs[prIndex].id, userId: exercisePRs[prIndex].userId,
                            exerciseId: exerciseId, recordType: .reps,
                            value: completedSet.weight, repsAtWeight: completedSet.reps,
                            sessionId: sessionId, achievedAt: Date(), createdAt: Date()
                        )
                        currentPRs[exerciseId] = exercisePRs
                    }
                }
            }
        }

        // Start elapsed timer on first confirmed set
        if !timerStarted {
            startTime = Date()
            startElapsedTimer()
            timerStarted = true
        }

        // Superset auto-advance: if in a superset and not the last exercise,
        // skip rest timer and scroll to next exercise in the stacked view.
        if isInSuperset(exerciseIndex),
           let nextIndex = nextSupersetExercise(after: exerciseIndex) {
            // Auto-scroll to next superset exercise within stacked view (no rest)
            scrollToExerciseIndex = nextIndex
        } else if isInSuperset(exerciseIndex) && isLastInSuperset(exerciseIndex) {
            // Last exercise in superset round: scroll back to first exercise for next round
            if let firstInGroup = currentGroupIndices.first {
                scrollToExerciseIndex = firstInGroup
            }
            // Start rest timer after completing the full superset round
            if restTimerEnabled {
                startRestTimer(seconds: restTimerDuration)
            }
        } else if restTimerEnabled {
            // Normal flow: start rest timer
            startRestTimer(seconds: restTimerDuration)
        }

        // Haptic feedback — always strong for PR, medium for normal sets
        if exercises[exerciseIndex].sets[setIndex].isPR {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        } else {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        // Auto-save workout state
        saveWorkoutState()
    }

    func uncompleteSet(exerciseIndex: Int, setIndex: Int) async {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let set = exercises[exerciseIndex].sets[setIndex]
        guard set.isCompleted, let savedId = set.savedSetId else { return }

        do {
            try await workoutService.deleteSet(id: savedId)
            exercises[exerciseIndex].sets[setIndex].isCompleted = false
            exercises[exerciseIndex].sets[setIndex].savedSetId = nil
        } catch {
            errorMessage = "Failed to undo set."
        }
    }

    /// Inserts 2 pre-filled warmup sets for compound barbell exercises:
    /// Warmup 1: ~50% of working weight × 10 reps
    /// Warmup 2: ~75% of working weight × 5 reps
    func addSuggestedWarmups(exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let exercise = exercises[exerciseIndex]

        // Use the first working set's weight as the reference
        let workingWeight = exercise.sets.first(where: { $0.setType == .working })?.weight
            ?? exercise.progressionTarget?.targetWeight ?? 0
        guard workingWeight > 0 else { return }

        let increment = ProgressionService.weightIncrement(for: exercise.equipment)

        let warmup1Weight = Self.roundToIncrement(workingWeight * 0.50, increment)
        let warmup2Weight = Self.roundToIncrement(workingWeight * 0.75, increment)

        let warmup1 = SetEntry(setNumber: 1, setType: .warmup, weight: warmup1Weight, reps: 10)
        let warmup2 = SetEntry(setNumber: 2, setType: .warmup, weight: warmup2Weight, reps: 5)

        // Insert at the beginning (before working sets)
        exercises[exerciseIndex].sets.insert(warmup2, at: 0)
        exercises[exerciseIndex].sets.insert(warmup1, at: 0)

        renumberSets(exerciseIndex: exerciseIndex)
    }

    /// Whether an exercise should show the warmup suggestion card.
    /// Only for barbell/smith machine hypertrophy exercises with no existing warmup sets.
    func shouldSuggestWarmup(exerciseIndex: Int) -> Bool {
        guard !dismissedWarmupSuggestions.contains(exerciseIndex) else { return false }
        guard let exercise = exercises[safe: exerciseIndex] else { return false }
        let isCompound = exercise.equipment == "barbell" || exercise.equipment == "smith_machine"
        let isHypertrophy = exercise.trainingMode == .hypertrophy
        let hasNoWarmups = !exercise.sets.contains(where: { $0.setType == .warmup })
        let hasWorkingWeight = exercise.sets.first(where: { $0.setType == .working })?.weight ?? 0 > 0
            || exercise.progressionTarget?.targetWeight ?? 0 > 0
        return isCompound && isHypertrophy && hasNoWarmups && hasWorkingWeight
    }

    func dismissWarmupSuggestion(exerciseIndex: Int) {
        dismissedWarmupSuggestions.insert(exerciseIndex)
    }

    /// Returns the suggested warmup weights for display in the suggestion card.
    func suggestedWarmupWeights(exerciseIndex: Int) -> (warmup1: Double, warmup2: Double)? {
        guard let exercise = exercises[safe: exerciseIndex] else { return nil }
        let workingWeight = exercise.sets.first(where: { $0.setType == .working })?.weight
            ?? exercise.progressionTarget?.targetWeight ?? 0
        guard workingWeight > 0 else { return nil }
        let increment = ProgressionService.weightIncrement(for: exercise.equipment)
        return (
            warmup1: Self.roundToIncrement(workingWeight * 0.50, increment),
            warmup2: Self.roundToIncrement(workingWeight * 0.75, increment)
        )
    }

    func addSet(exerciseIndex: Int, setType: SetType = .working) {
        guard exercises.indices.contains(exerciseIndex) else { return }

        let currentSets = exercises[exerciseIndex].sets
        // Find the last set of the same type for pre-filling weight
        let lastSameType = currentSets.last(where: { $0.setType == setType })
        let lastAny = currentSets.last
        let newSetNumber = (currentSets.last?.setNumber ?? 0) + 1

        let prefillWeight: Double
        switch setType {
        case .warmup, .cooldown:
            // Never pre-fill warmup or cooldown sets
            prefillWeight = 0
        default:
            prefillWeight = lastSameType?.weight ?? lastAny?.weight ?? 0
        }

        let newSet = SetEntry(
            setNumber: newSetNumber,
            setType: setType,
            weight: prefillWeight,
            reps: 0
        )

        // Insert in the right position: group by type sort order
        let insertIndex = findInsertIndex(for: setType, in: currentSets)
        exercises[exerciseIndex].sets.insert(newSet, at: insertIndex)

        // Renumber all sets
        renumberSets(exerciseIndex: exerciseIndex)
    }

    /// Find the correct insertion index to keep sets grouped by type.
    private func findInsertIndex(for setType: SetType, in sets: [SetEntry]) -> Int {
        // Find the last set with the same or lower sort order
        var insertAt = sets.count
        for (index, existingSet) in sets.enumerated().reversed() {
            if existingSet.setType.sortOrder <= setType.sortOrder {
                insertAt = index + 1
                break
            }
        }
        // If no set with lower/equal sort order found, insert at beginning
        if insertAt == sets.count && !sets.isEmpty {
            if let first = sets.first, first.setType.sortOrder > setType.sortOrder {
                insertAt = 0
            }
        }
        return insertAt
    }

    private func renumberSets(exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        for i in exercises[exerciseIndex].sets.indices {
            exercises[exerciseIndex].sets[i].setNumber = i + 1
        }
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) async {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let set = exercises[exerciseIndex].sets[setIndex]

        // If completed, delete from DB first
        if let savedId = set.savedSetId {
            do {
                try await workoutService.deleteSet(id: savedId)
            } catch {
                errorMessage = "Failed to remove set."
                return
            }
        }

        exercises[exerciseIndex].sets.remove(at: setIndex)
        renumberSets(exerciseIndex: exerciseIndex)
    }

    func updateWeight(exerciseIndex: Int, setIndex: Int, weight: Double) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex),
              !exercises[exerciseIndex].sets[setIndex].isCompleted else { return }
        exercises[exerciseIndex].sets[setIndex].weight = weight
    }

    func updateReps(exerciseIndex: Int, setIndex: Int, reps: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex),
              !exercises[exerciseIndex].sets[setIndex].isCompleted else { return }
        exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    func updateRPE(exerciseIndex: Int, setIndex: Int, rpe: Double?) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex),
              !exercises[exerciseIndex].sets[setIndex].isCompleted else { return }
        exercises[exerciseIndex].sets[setIndex].rpe = rpe
    }

    func updateSetType(exerciseIndex: Int, setIndex: Int, setType: SetType) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex),
              !exercises[exerciseIndex].sets[setIndex].isCompleted else { return }
        exercises[exerciseIndex].sets[setIndex].setType = setType
    }

    // MARK: - Auto-Save & Recovery

    /// Saves current workout state to disk for crash recovery.
    func saveWorkoutState() {
        guard let sessionId else { return }

        let savedExercises = exercises.map { exercise in
            SavedExerciseState(
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.exerciseName,
                muscleGroup: exercise.muscleGroup,
                equipment: exercise.equipment,
                trainingMode: exercise.trainingMode,
                targetSets: exercise.targetSets,
                sortOrder: exercise.sortOrder,
                sets: exercise.sets.map { set in
                    SavedSetState(
                        setNumber: set.setNumber,
                        setType: set.setType,
                        weight: set.weight,
                        reps: set.reps,
                        rpe: set.rpe,
                        isCompleted: set.isCompleted,
                        savedSetId: set.savedSetId
                    )
                },
                originalExerciseId: exercise.originalExerciseId,
                supersetGroup: exercise.supersetGroup
            )
        }

        let state = SavedWorkoutState(
            sessionId: sessionId,
            templateName: templateName,
            dayName: dayName,
            startTime: startTime,
            exercises: savedExercises
        )
        WorkoutAutoSave.save(state)
    }

    /// Restores workout state from a saved snapshot (crash recovery).
    func restoreFromSavedState(_ state: SavedWorkoutState) {
        sessionId = state.sessionId
        templateName = state.templateName
        dayName = state.dayName
        startTime = state.startTime
        elapsedSeconds = Int(Date().timeIntervalSince(state.startTime))

        exercises = state.exercises.map { saved in
            ExerciseLogEntry(
                id: UUID(),
                exerciseId: saved.exerciseId,
                exerciseName: saved.exerciseName,
                muscleGroup: saved.muscleGroup,
                equipment: saved.equipment,
                trainingMode: saved.trainingMode,
                targetSets: saved.targetSets,
                restSeconds: AppConstants.Defaults.restTimerSeconds,
                sortOrder: saved.sortOrder,
                sets: saved.sets.map { savedSet in
                    var entry = SetEntry(
                        setNumber: savedSet.setNumber,
                        setType: savedSet.setType,
                        weight: savedSet.weight,
                        reps: savedSet.reps,
                        rpe: savedSet.rpe
                    )
                    entry.isCompleted = savedSet.isCompleted
                    entry.savedSetId = savedSet.savedSetId
                    return entry
                },
                previousSets: [],
                originalExerciseId: saved.originalExerciseId,
                supersetGroup: saved.supersetGroup
            )
        }

        // Start timers
        startElapsedTimer()
        timerStarted = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Starts periodic auto-save (every 30 seconds).
    private func startAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { break }
                self.saveWorkoutState()
            }
        }
    }

    /// Syncs any pending offline sets.
    func syncOfflineSets() async {
        await OfflineSetQueue.shared.syncPendingSets()
    }

    // MARK: - Exercise Substitution

    /// Substitutes the exercise at the given index with a new exercise.
    /// Per user requirement: no target carryover from original exercise.
    /// If the user has logged the substitute exercise before, pre-fill from that data.
    func substituteExercise(at exerciseIndex: Int, with newExercise: Exercise) async {
        guard exercises.indices.contains(exerciseIndex) else { return }

        let original = exercises[exerciseIndex]

        // Fetch previous session data for the NEW exercise (if user has logged it before)
        var previousSets: [WorkoutSet] = []
        if let userId = try? await supabase.auth.session.user.id {
            let history = (try? await workoutService.fetchPreviousSetsForExercise(
                exerciseId: newExercise.id,
                userId: userId,
                limit: 1
            )) ?? []
            previousSets = history.first ?? []
        }

        // Build new sets: pre-fill from substitute's history or leave blank
        var newSets: [SetEntry] = []
        for i in 1...original.targetSets {
            let prev = previousSets[safe: i - 1]
            newSets.append(SetEntry(
                setNumber: i,
                setType: .working,
                weight: prev?.weight ?? 0,
                reps: prev?.reps ?? 0
            ))
        }

        // Replace exercise data — NO progression target carryover
        exercises[exerciseIndex].originalExerciseId = original.exerciseId
        exercises[exerciseIndex].exerciseId = newExercise.id
        exercises[exerciseIndex].exerciseName = newExercise.name
        exercises[exerciseIndex].muscleGroup = newExercise.muscleGroup
        exercises[exerciseIndex].equipment = newExercise.equipment
        exercises[exerciseIndex].previousSets = previousSets.isEmpty ? [] : [previousSets]
        exercises[exerciseIndex].progressionTarget = nil // No carryover

        // Remove uncompleted sets and add new ones
        let completedSets = original.sets.filter(\.isCompleted)
        exercises[exerciseIndex].sets = completedSets + newSets

        // Renumber
        renumberSets(exerciseIndex: exerciseIndex)

        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Superset Support

    /// Returns the exercises in the same superset group as the given exercise index.
    /// Returns an empty array if the exercise is not in a superset.
    func supersetExercises(for exerciseIndex: Int) -> [(index: Int, entry: ExerciseLogEntry)] {
        guard let group = exercises[safe: exerciseIndex]?.supersetGroup else { return [] }
        return exercises.enumerated()
            .filter { $0.element.supersetGroup == group }
            .map { (index: $0.offset, entry: $0.element) }
    }

    /// Returns true if the exercise at the given index is part of a superset.
    func isInSuperset(_ exerciseIndex: Int) -> Bool {
        exercises[safe: exerciseIndex]?.supersetGroup != nil
    }

    /// Returns the next exercise in the superset after the given index, or nil.
    func nextSupersetExercise(after exerciseIndex: Int) -> Int? {
        guard let group = exercises[safe: exerciseIndex]?.supersetGroup else { return nil }
        let supersetMembers = exercises.enumerated()
            .filter { $0.element.supersetGroup == group }
            .map(\.offset)
        guard let currentPos = supersetMembers.firstIndex(of: exerciseIndex) else { return nil }
        let nextPos = currentPos + 1
        if nextPos < supersetMembers.count {
            return supersetMembers[nextPos]
        }
        return nil // End of superset round
    }

    /// Returns true if this exercise is the last in its superset group.
    func isLastInSuperset(_ exerciseIndex: Int) -> Bool {
        return nextSupersetExercise(after: exerciseIndex) == nil
    }

    // MARK: - Ad-Hoc Supersets (session-only, not persisted to template)

    /// Returns exercises available to superset with the given exercise.
    func availableExercisesForSuperset(excluding exerciseIndex: Int) -> [(index: Int, name: String)] {
        let currentGroup = exercises[safe: exerciseIndex]?.supersetGroup
        return exercises.enumerated()
            .filter { idx, ex in
                guard idx != exerciseIndex else { return false }
                // If the source exercise isn't in a superset, show all other exercises
                guard let currentGroup else { return true }
                // If the source is in a superset, exclude exercises already in the same group
                return ex.supersetGroup != currentGroup
            }
            .map { (index: $0.offset, name: $0.element.exerciseName) }
    }

    /// Creates a session-only superset between two exercises.
    func createAdHocSuperset(exerciseIndex: Int, withExerciseIndex: Int) {
        let newGroup = (exercises.compactMap(\.supersetGroup).max() ?? -1) + 1
        exercises[exerciseIndex].supersetGroup = newGroup
        exercises[withExerciseIndex].supersetGroup = newGroup

        // Reorder so they're adjacent
        let targetIdx = withExerciseIndex
        let destIdx = exerciseIndex + 1

        if targetIdx != destIdx {
            let exercise = exercises.remove(at: targetIdx)
            let insertAt = targetIdx < destIdx ? destIdx - 1 : destIdx
            exercises.insert(exercise, at: insertAt)
        }

        // Navigate to the group start
        let groupStart = exercises.enumerated()
            .filter { $0.element.supersetGroup == newGroup }
            .map(\.offset)
            .first ?? exerciseIndex
        currentExerciseIndex = groupStart
    }

    /// Removes an exercise from its ad-hoc superset group.
    func removeFromAdHocSuperset(exerciseIndex: Int) {
        guard let group = exercises[safe: exerciseIndex]?.supersetGroup else { return }
        exercises[exerciseIndex].supersetGroup = nil

        // If only 1 exercise remains in the group, remove it too
        let remaining = exercises.enumerated().filter { $0.element.supersetGroup == group }
        if remaining.count == 1, let orphan = remaining.first {
            exercises[orphan.offset].supersetGroup = nil
        }
    }

    // MARK: - Bodyweight Weight Toggle

    func toggleAddedWeight(exerciseIndex: Int) {
        guard exercises[safe: exerciseIndex] != nil else { return }
        exercises[exerciseIndex].useAddedWeight.toggle()
    }

    // MARK: - Timers

    private func startElapsedTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
            }
        }
    }

    func adjustRestTimerDuration(by delta: Int) {
        let newDuration = restTimerDuration + delta
        restTimerDuration = max(15, min(600, newDuration)) // 15s – 10min
    }

    /// Add time to the currently running rest timer.
    func adjustRunningTimer(by delta: Int) {
        guard restTimerActive else { return }
        let newRemaining = restTimerRemaining + delta
        let newTarget = restTimerTarget + delta
        restTimerRemaining = max(0, newRemaining)
        restTimerTarget = max(1, newTarget)
        if restTimerRemaining == 0 {
            cancelRestTimer()
        }
    }

    func startRestTimer(seconds: Int) {
        cancelRestTimer()
        restTimerTarget = seconds
        restTimerRemaining = seconds
        restTimerActive = true

        restTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                if self.restTimerRemaining > 0 {
                    self.restTimerRemaining -= 1
                } else {
                    self.restTimerActive = false
                    // Haptic when timer completes
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    break
                }
            }
        }
    }

    func cancelRestTimer() {
        restTimerTask?.cancel()
        restTimerActive = false
        restTimerRemaining = 0
        restTimerTarget = 0
    }

    private func formatWeightForPR(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
