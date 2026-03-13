import Foundation
import Supabase

@Observable
final class ProgramBrowserViewModel {
    var selectedCategory: ProgramCategory? = nil
    var programs: [ProgramDefinition] = ProgramCatalog.allPrograms
    var isMaterializing = false
    var errorMessage: String?
    var materializedTemplate: Template?

    func filterByCategory(_ category: ProgramCategory?) {
        selectedCategory = category
        if let category {
            programs = ProgramCatalog.programs(in: category)
        } else {
            programs = ProgramCatalog.allPrograms
        }
    }

    /// Materializes a program into the user's Supabase templates.
    /// Resolves exercise names → UUIDs from the built-in exercise library,
    /// creates a template with workout days and exercises.
    func materializeProgram(_ program: ProgramDefinition) async {
        isMaterializing = true
        errorMessage = nil
        materializedTemplate = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                errorMessage = "Not signed in."
                isMaterializing = false
                return
            }

            // 1. Fetch all built-in exercises to resolve names → UUIDs
            let exerciseService = ExerciseLibraryService()
            let allExercises = try await exerciseService.fetchExercises()
            let nameToExercise = Dictionary(
                allExercises.map { ($0.name.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            // 2. Collect all exercise names used in this program
            let allExerciseNames = Set(program.days.flatMap { $0.exercises.map { $0.exerciseName } })

            // 3. Verify all exercises can be resolved
            var missingExercises: [String] = []
            for name in allExerciseNames {
                if nameToExercise[name.lowercased()] == nil {
                    missingExercises.append(name)
                }
            }
            if !missingExercises.isEmpty {
                errorMessage = "Missing exercises: \(missingExercises.joined(separator: ", "))"
                isMaterializing = false
                return
            }

            // 4. Create the template
            let templateService = TemplateService()
            let template = try await templateService.createTemplate(
                userId: userId,
                name: program.name,
                description: program.description,
                sourceProgram: program.id
            )

            // 5. Create workout days and their exercises
            for (dayIndex, day) in program.days.enumerated() {
                let workoutDay = try await templateService.createWorkoutDay(
                    templateId: template.id,
                    name: day.name,
                    description: day.description,
                    sortOrder: dayIndex
                )

                for (exIndex, exercise) in day.exercises.enumerated() {
                    guard let resolved = nameToExercise[exercise.exerciseName.lowercased()] else {
                        continue
                    }
                    _ = try await templateService.addExerciseToDay(
                        workoutDayId: workoutDay.id,
                        exerciseId: resolved.id,
                        trainingMode: exercise.trainingMode,
                        targetSets: exercise.targetSets,
                        sortOrder: exIndex
                    )
                }
            }

            // 6. Fetch the complete template with nested data
            materializedTemplate = try await templateService.fetchTemplate(id: template.id)
        } catch {
            errorMessage = "Failed to create template: \(error.localizedDescription)"
        }
        isMaterializing = false
    }
}
