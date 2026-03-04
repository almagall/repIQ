import Foundation
import Supabase

@Observable
final class TemplateEditorViewModel {
    var templateName = ""
    var templateDescription = ""
    var workoutDays: [WorkoutDay] = []
    var isLoading = false
    var errorMessage: String?
    var isSaved = false

    private var templateId: UUID?
    private var isEditing: Bool { templateId != nil }
    private let templateService = TemplateService()

    var isFormValid: Bool {
        !templateName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Load existing template for editing

    func loadTemplate(_ template: Template) {
        templateId = template.id
        templateName = template.name
        templateDescription = template.description ?? ""
        workoutDays = template.workoutDays ?? []
    }

    // MARK: - Save Template

    func save() async {
        guard isFormValid else {
            errorMessage = "Please enter a template name."
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            if let templateId {
                try await templateService.updateTemplate(
                    id: templateId,
                    name: templateName.trimmingCharacters(in: .whitespaces),
                    description: templateDescription.isEmpty ? nil : templateDescription
                )
            } else {
                guard let userId = try? await supabase.auth.session.user.id else { return }
                let template = try await templateService.createTemplate(
                    userId: userId,
                    name: templateName.trimmingCharacters(in: .whitespaces),
                    description: templateDescription.isEmpty ? nil : templateDescription
                )
                templateId = template.id
            }
            isSaved = true
        } catch {
            errorMessage = "Failed to save template."
        }
        isLoading = false
    }

    // MARK: - Workout Days

    func addWorkoutDay(name: String, description: String?) async {
        guard let templateId else {
            errorMessage = "Save the template first before adding days."
            return
        }
        isLoading = true
        do {
            let day = try await templateService.createWorkoutDay(
                templateId: templateId,
                name: name,
                description: description,
                sortOrder: workoutDays.count
            )
            workoutDays.append(day)
        } catch {
            errorMessage = "Failed to add workout day."
        }
        isLoading = false
    }

    func deleteWorkoutDay(_ day: WorkoutDay) async {
        isLoading = true
        do {
            try await templateService.deleteWorkoutDay(id: day.id)
            workoutDays.removeAll { $0.id == day.id }
        } catch {
            errorMessage = "Failed to delete workout day."
        }
        isLoading = false
    }

    func updateWorkoutDay(_ day: WorkoutDay, name: String, description: String?) async {
        do {
            try await templateService.updateWorkoutDay(id: day.id, name: name, description: description)
            if let index = workoutDays.firstIndex(where: { $0.id == day.id }) {
                workoutDays[index].name = name
                workoutDays[index].description = description
            }
        } catch {
            errorMessage = "Failed to update workout day."
        }
    }

    // MARK: - Exercises within a day

    func addExercise(to day: WorkoutDay, exercise: Exercise, trainingMode: TrainingMode, targetSets: Int = 3) async {
        isLoading = true
        do {
            let currentCount = day.exercises?.count ?? 0
            let dayExercise = try await templateService.addExerciseToDay(
                workoutDayId: day.id,
                exerciseId: exercise.id,
                trainingMode: trainingMode,
                targetSets: targetSets,
                sortOrder: currentCount
            )
            if let dayIndex = workoutDays.firstIndex(where: { $0.id == day.id }) {
                if workoutDays[dayIndex].exercises == nil {
                    workoutDays[dayIndex].exercises = []
                }
                workoutDays[dayIndex].exercises?.append(dayExercise)
            }
        } catch {
            errorMessage = "Failed to add exercise."
        }
        isLoading = false
    }

    func removeExercise(_ dayExercise: WorkoutDayExercise, from day: WorkoutDay) async {
        do {
            try await templateService.removeDayExercise(id: dayExercise.id)
            if let dayIndex = workoutDays.firstIndex(where: { $0.id == day.id }) {
                workoutDays[dayIndex].exercises?.removeAll { $0.id == dayExercise.id }
            }
        } catch {
            errorMessage = "Failed to remove exercise."
        }
    }

    func updateExerciseMode(_ dayExercise: WorkoutDayExercise, trainingMode: TrainingMode, targetSets: Int) async {
        do {
            try await templateService.updateDayExercise(
                id: dayExercise.id,
                trainingMode: trainingMode,
                targetSets: targetSets
            )
            for dayIndex in workoutDays.indices {
                if let exIndex = workoutDays[dayIndex].exercises?.firstIndex(where: { $0.id == dayExercise.id }) {
                    workoutDays[dayIndex].exercises?[exIndex].trainingMode = trainingMode
                    workoutDays[dayIndex].exercises?[exIndex].targetSets = targetSets
                }
            }
        } catch {
            errorMessage = "Failed to update exercise."
        }
    }

    // MARK: - Reload

    func reload() async {
        guard let templateId else { return }
        do {
            let template = try await templateService.fetchTemplate(id: templateId)
            workoutDays = template.workoutDays ?? []
        } catch {
            errorMessage = "Failed to reload template."
        }
    }
}
