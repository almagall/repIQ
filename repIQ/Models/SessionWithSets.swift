import Foundation

struct SessionWithSets: Identifiable, Sendable {
    let session: WorkoutSession
    let sets: [WorkoutSet]
    let exerciseNames: [UUID: String]

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
}
