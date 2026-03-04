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

    // MARK: - Rest Timer
    var restTimerRemaining: Int = 0
    var restTimerTarget: Int = 0
    var restTimerActive = false
    var restTimerEnabled = true
    var restTimerDuration: Int = AppConstants.Defaults.restTimerSeconds

    /// Preset durations available for quick selection (in seconds).
    static let timerPresets: [Int] = [30, 60, 90, 120, 150, 180, 240, 300]

    // MARK: - Context
    private(set) var templateName: String = ""
    private(set) var dayName: String = ""

    // MARK: - Private
    private let workoutService = WorkoutService()
    private var timerTask: Task<Void, Never>?
    private var restTimerTask: Task<Void, Never>?

    deinit {
        timerTask?.cancel()
        restTimerTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Computed

    var elapsedDisplay: String {
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
        currentExerciseIndex > 0
    }

    var canGoToNext: Bool {
        currentExerciseIndex < exercises.count - 1
    }

    // MARK: - Exercise Navigation

    func goToPreviousExercise() {
        guard canGoToPrevious else { return }
        currentExerciseIndex -= 1
    }

    func goToNextExercise() {
        guard canGoToNext else { return }
        currentExerciseIndex += 1
    }

    func goToExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
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

            // 3. Fetch previous session data for all exercises
            let previousData = try await workoutService.fetchPreviousSetsForExercises(
                exerciseIds: exerciseIds,
                userId: userId
            )

            // 4. Build ExerciseLogEntry array
            exercises = dayExercises.sorted(by: { $0.sortOrder < $1.sortOrder }).map { dayExercise in
                let prevSets = previousData[dayExercise.exerciseId] ?? []
                let restSeconds = dayExercise.restSecondsOverride
                    ?? dayExercise.exercise?.defaultRestSeconds
                    ?? AppConstants.Defaults.restTimerSeconds

                // Pre-fill sets from template target count
                var sets: [SetEntry] = []
                for i in 1...dayExercise.targetSets {
                    let previousSet = prevSets[safe: i - 1]
                    sets.append(SetEntry(
                        setNumber: i,
                        setType: .working,
                        weight: previousSet?.weight ?? 0,
                        reps: previousSet.map { _ in 0 } ?? 0
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
                    isExpanded: false
                )
            }

            // 5. Start elapsed timer
            startElapsedTimer()

            // 6. Keep screen awake during workout
            UIApplication.shared.isIdleTimerDisabled = true

        } catch {
            errorMessage = "Failed to start workout: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func completeWorkout() async {
        guard let sessionId else { return }
        isLoading = true

        do {
            let duration = Int(Date().timeIntervalSince(startTime))
            try await workoutService.completeSession(
                sessionId: sessionId,
                durationSeconds: duration
            )

            // Build summary
            workoutSummary = WorkoutSummaryData(
                duration: duration,
                totalSets: totalCompletedSets,
                totalVolume: totalVolume,
                exerciseSummaries: exercises.compactMap { exercise in
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
            )

            timerTask?.cancel()
            cancelRestTimer()
            UIApplication.shared.isIdleTimerDisabled = false

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
        cancelRestTimer()
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

            // Start rest timer if enabled
            if restTimerEnabled {
                startRestTimer(seconds: restTimerDuration)
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

        } catch {
            exercises[exerciseIndex].sets[setIndex].isSaving = false
            errorMessage = "Failed to save set."
        }
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

    func addSet(exerciseIndex: Int, setType: SetType = .working) {
        guard exercises.indices.contains(exerciseIndex) else { return }

        let currentSets = exercises[exerciseIndex].sets
        // Find the last set of the same type for pre-filling weight
        let lastSameType = currentSets.last(where: { $0.setType == setType })
        let lastAny = currentSets.last
        let newSetNumber = (currentSets.last?.setNumber ?? 0) + 1

        let prefillWeight: Double
        switch setType {
        case .warmup:
            // Warm-up: use half of last working set weight, or 0
            let workingWeight = currentSets.last(where: { $0.setType == .working })?.weight ?? 0
            prefillWeight = lastSameType?.weight ?? (workingWeight * 0.5)
        case .cooldown:
            let workingWeight = currentSets.last(where: { $0.setType == .working })?.weight ?? 0
            prefillWeight = lastSameType?.weight ?? (workingWeight * 0.5)
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

    func togglePreviousSets(exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].isExpanded.toggle()
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
}
