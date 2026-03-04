import Foundation
import Supabase

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved
    case error(String)
}

@Observable
final class TemplateEditorViewModel {
    var templateName = "" {
        didSet {
            if templateName != oldValue {
                scheduleAutoSave()
            }
        }
    }
    var templateDescription = "" {
        didSet {
            if templateDescription != oldValue {
                scheduleAutoSave()
            }
        }
    }
    var workoutDays: [WorkoutDay] = []
    var isLoading = false
    var errorMessage: String?
    var saveStatus: SaveStatus = .idle

    /// Whether the template exists in the database (has been created).
    var isSaved: Bool { templateId != nil }

    private var templateId: UUID?
    private var isEditing: Bool { templateId != nil }
    private let templateService = TemplateService()
    private var autoSaveTask: Task<Void, Never>?

    /// Debounce interval for auto-save (seconds).
    private let autoSaveDelay: Duration = .milliseconds(800)

    deinit {
        autoSaveTask?.cancel()
    }

    var isFormValid: Bool {
        !templateName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Load existing template for editing

    func loadTemplate(_ template: Template) {
        templateId = template.id
        templateName = template.name
        templateDescription = template.description ?? ""
        workoutDays = template.workoutDays ?? []
        saveStatus = .saved
    }

    // MARK: - Auto-Save

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(for: self?.autoSaveDelay ?? .milliseconds(800))
            guard let self, !Task.isCancelled else { return }
            await self.autoSave()
        }
    }

    /// Creates the template if it doesn't exist, or updates it if it does.
    private func autoSave() async {
        guard isFormValid else {
            // Don't save if name is empty, but clear any previous error
            if case .error = saveStatus {} else {
                saveStatus = .idle
            }
            return
        }

        saveStatus = .saving

        do {
            if let templateId {
                // Update existing
                try await templateService.updateTemplate(
                    id: templateId,
                    name: templateName.trimmingCharacters(in: .whitespaces),
                    description: templateDescription.isEmpty ? nil : templateDescription
                )
            } else {
                // Create new
                guard let userId = try? await supabase.auth.session.user.id else {
                    saveStatus = .error("Not authenticated.")
                    return
                }
                let template = try await templateService.createTemplate(
                    userId: userId,
                    name: templateName.trimmingCharacters(in: .whitespaces),
                    description: templateDescription.isEmpty ? nil : templateDescription
                )
                templateId = template.id
            }
            saveStatus = .saved
            errorMessage = nil
        } catch {
            saveStatus = .error("Failed to save.")
            errorMessage = "Failed to save template."
        }
    }

    /// Force-save immediately (e.g. before dismissing).
    func flushSave() async {
        autoSaveTask?.cancel()
        guard isFormValid else { return }
        await autoSave()
    }

    // MARK: - Workout Days

    func addWorkoutDay(name: String, description: String?) async {
        // Auto-create template if it hasn't been saved yet
        if templateId == nil {
            guard isFormValid else {
                errorMessage = "Please enter a template name first."
                return
            }
            await autoSave()
            guard templateId != nil else { return }
        }

        guard let templateId else { return }
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
