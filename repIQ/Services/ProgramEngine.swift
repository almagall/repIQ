import Foundation

protocol ProgramEngine {
    var programId: String { get }
    func computeSetTargets(
        exerciseId: UUID,
        trainingMax: Double,
        weekNumber: Int,
        setPosition: Int
    ) -> (weight: Double, reps: Int, rpe: Double)?
    func computeProgression(
        exerciseId: UUID,
        trainingMax: Double,
        completedSets: [WorkoutSet],
        weekNumber: Int
    ) -> ProgressionTarget?
}
