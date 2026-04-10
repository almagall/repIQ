import Foundation

/// Periodically saves the active workout state to disk for crash recovery.
/// If the app is killed or crashes during a workout, the state can be restored.
struct WorkoutAutoSave {
    private static let fileURL: URL = {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("active_workout_state.json")
    }()

    // MARK: - Save

    /// Saves the current workout state to disk.
    static func save(_ state: SavedWorkoutState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort — don't crash the workout for a save failure
        }
    }

    // MARK: - Load

    /// Loads a previously saved workout state, if one exists.
    static func load() -> SavedWorkoutState? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SavedWorkoutState.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Clear

    /// Removes the saved state (called on workout completion/abandonment).
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Returns true if there is a recoverable workout state on disk.
    static var hasRecoverableState: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}

/// The serializable snapshot of an active workout session.
struct SavedWorkoutState: Codable {
    let sessionId: UUID
    let workoutDayId: UUID?
    let templateName: String
    let dayName: String
    let startTime: Date
    let exercises: [SavedExerciseState]
    let savedAt: Date

    init(
        sessionId: UUID,
        workoutDayId: UUID? = nil,
        templateName: String,
        dayName: String,
        startTime: Date,
        exercises: [SavedExerciseState]
    ) {
        self.sessionId = sessionId
        self.workoutDayId = workoutDayId
        self.templateName = templateName
        self.dayName = dayName
        self.startTime = startTime
        self.exercises = exercises
        self.savedAt = Date()
    }
}

/// Serializable exercise state within a saved workout.
struct SavedExerciseState: Codable {
    let exerciseId: UUID
    let exerciseName: String
    let muscleGroup: String
    let equipment: String
    let trainingMode: TrainingMode
    let targetSets: Int
    let sortOrder: Int
    let sets: [SavedSetState]
    let originalExerciseId: UUID?
    let supersetGroup: Int?
}

/// Serializable set state.
struct SavedSetState: Codable {
    let setNumber: Int
    let setType: SetType
    let weight: Double
    let reps: Int
    let rpe: Double?
    let isCompleted: Bool
    let savedSetId: UUID?
}
