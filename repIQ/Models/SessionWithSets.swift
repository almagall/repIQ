import Foundation

struct SessionWithSets: Identifiable, Sendable {
    let session: WorkoutSession
    let sets: [WorkoutSet]
    let exerciseNames: [UUID: String]
    let exerciseMuscleGroups: [UUID: String]

    init(session: WorkoutSession, sets: [WorkoutSet], exerciseNames: [UUID: String], exerciseMuscleGroups: [UUID: String] = [:]) {
        self.session = session
        self.sets = sets
        self.exerciseNames = exerciseNames
        self.exerciseMuscleGroups = exerciseMuscleGroups
    }

    var id: UUID { session.id }
    var totalVolume: Double { sets.reduce(0) { $0 + $1.volume } }
    var totalSets: Int { sets.count }
    var exerciseCount: Int { Set(sets.map(\.exerciseId)).count }
    var topWeight: Double { sets.map(\.weight).max() ?? 0 }

    /// Sets grouped by exercise ID, preserving order of first appearance.
    var setsByExercise: [(exerciseId: UUID, name: String, sets: [WorkoutSet])] {
        var seen: [UUID] = []
        var grouped: [UUID: [WorkoutSet]] = [:]

        for set in sets {
            if !seen.contains(set.exerciseId) {
                seen.append(set.exerciseId)
            }
            grouped[set.exerciseId, default: []].append(set)
        }

        return seen.map { exerciseId in
            (
                exerciseId: exerciseId,
                name: exerciseNames[exerciseId] ?? "Unknown Exercise",
                sets: grouped[exerciseId] ?? []
            )
        }
    }

    /// Builds a WorkoutSummaryData from the historical session data for display in WorkoutSummaryView.
    func buildSummaryData(workoutName: String = "", dayName: String = "") -> WorkoutSummaryData {
        let exerciseSummaries: [WorkoutSummaryData.ExerciseSummary] = setsByExercise.compactMap { group in
            let workingSets = group.sets.filter {
                $0.setType == .working || $0.setType == .drop || $0.setType == .failure
            }
            guard !workingSets.isEmpty else { return nil }
            return WorkoutSummaryData.ExerciseSummary(
                id: group.exerciseId,
                name: group.name,
                muscleGroup: exerciseMuscleGroups[group.exerciseId] ?? "",
                trainingMode: .hypertrophy,
                setsCompleted: workingSets.count,
                totalVolume: workingSets.reduce(0) { $0 + $1.volume },
                topWeight: workingSets.map(\.weight).max() ?? 0,
                topReps: workingSets.map(\.reps).max() ?? 0
            )
        }

        let prSummaries: [PRSummary] = sets.filter(\.isPR).map { set in
            PRSummary(
                exerciseName: exerciseNames[set.exerciseId] ?? "Unknown",
                recordType: .weight,
                value: set.weight,
                previousValue: nil
            )
        }

        var data = WorkoutSummaryData(
            duration: session.durationSeconds ?? 0,
            totalSets: totalSets,
            totalVolume: totalVolume,
            exerciseSummaries: exerciseSummaries,
            newPRs: prSummaries
        )
        data.workoutName = workoutName
        data.dayName = dayName
        data.workoutDate = session.completedAt ?? session.startedAt
        return data
    }
}
