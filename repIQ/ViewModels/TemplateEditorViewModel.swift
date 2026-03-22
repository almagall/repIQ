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

    func updateExerciseMode(_ dayExercise: WorkoutDayExercise, trainingMode: TrainingMode, targetSets: Int, repCap: Int? = nil) async {
        do {
            try await templateService.updateDayExercise(
                id: dayExercise.id,
                trainingMode: trainingMode,
                targetSets: targetSets,
                repCap: repCap
            )
            for dayIndex in workoutDays.indices {
                if let exIndex = workoutDays[dayIndex].exercises?.firstIndex(where: { $0.id == dayExercise.id }) {
                    workoutDays[dayIndex].exercises?[exIndex].trainingMode = trainingMode
                    workoutDays[dayIndex].exercises?[exIndex].targetSets = targetSets
                    workoutDays[dayIndex].exercises?[exIndex].repCap = repCap
                }
            }
        } catch {
            errorMessage = "Failed to update exercise."
        }
    }

    // MARK: - Reorder Exercises

    func moveExercise(in day: WorkoutDay, from sourceIndex: Int, to destinationIndex: Int) async {
        guard let dayIndex = workoutDays.firstIndex(where: { $0.id == day.id }),
              var exercises = workoutDays[dayIndex].exercises,
              exercises.indices.contains(sourceIndex),
              destinationIndex >= 0 && destinationIndex < exercises.count else { return }

        // Swap locally
        let moved = exercises.remove(at: sourceIndex)
        exercises.insert(moved, at: destinationIndex)

        // Update sort orders locally
        for i in exercises.indices {
            exercises[i].sortOrder = i
        }
        workoutDays[dayIndex].exercises = exercises

        // Persist all sort orders to Supabase
        do {
            for exercise in exercises {
                try await templateService.updateDayExerciseSortOrder(
                    id: exercise.id,
                    sortOrder: exercise.sortOrder
                )
            }
        } catch {
            errorMessage = "Failed to reorder exercises."
        }
    }

    // MARK: - Superset Management

    /// Creates a superset from the source exercise and the selected partner exercises.
    /// Any exercises previously in the source's superset group that are no longer selected get removed.
    func setSuperset(source: WorkoutDayExercise, partners: Set<UUID>, in day: WorkoutDay) async {
        guard let dayIndex = workoutDays.firstIndex(where: { $0.id == day.id }),
              let exercises = workoutDays[dayIndex].exercises else { return }

        // All exercises that should be in this superset (source + partners)
        let allMemberIds = partners.union([source.id])

        if partners.isEmpty {
            // Remove source from any superset
            await updateSupersetGroup(for: source, group: nil, dayIndex: dayIndex)
            // Clean up orphaned superset members (if only 1 left in group, remove it too)
            if let oldGroup = source.supersetGroup {
                let remaining = exercises.filter { $0.supersetGroup == oldGroup && $0.id != source.id }
                if remaining.count == 1, let orphan = remaining.first {
                    await updateSupersetGroup(for: orphan, group: nil, dayIndex: dayIndex)
                }
            }
            return
        }

        // Determine the group number to use
        let existingGroup = source.supersetGroup
            ?? partners.compactMap({ pid in exercises.first(where: { $0.id == pid })?.supersetGroup }).first
        let group: Int
        if let existing = existingGroup {
            group = existing
        } else {
            let maxGroup = exercises.compactMap(\.supersetGroup).max() ?? -1
            group = maxGroup + 1
        }

        // Set group for all members
        for exercise in exercises {
            if allMemberIds.contains(exercise.id) {
                if exercise.supersetGroup != group {
                    await updateSupersetGroup(for: exercise, group: group, dayIndex: dayIndex)
                }
            } else if exercise.supersetGroup == group {
                // Was in this group but no longer selected — remove
                await updateSupersetGroup(for: exercise, group: nil, dayIndex: dayIndex)
            }
        }
    }

    /// Removes an exercise from its superset group.
    func removeFromSuperset(_ dayExercise: WorkoutDayExercise, in day: WorkoutDay) async {
        guard let dayIndex = workoutDays.firstIndex(where: { $0.id == day.id }),
              let exercises = workoutDays[dayIndex].exercises else { return }

        let oldGroup = dayExercise.supersetGroup
        await updateSupersetGroup(for: dayExercise, group: nil, dayIndex: dayIndex)

        // If only 1 exercise remains in the old group, remove it too
        if let oldGroup {
            let remaining = exercises.filter { $0.supersetGroup == oldGroup && $0.id != dayExercise.id }
            if remaining.count == 1, let orphan = remaining.first {
                await updateSupersetGroup(for: orphan, group: nil, dayIndex: dayIndex)
            }
        }
    }

    private func updateSupersetGroup(for dayExercise: WorkoutDayExercise, group: Int?, dayIndex: Int) async {
        do {
            try await templateService.updateSupersetGroup(id: dayExercise.id, supersetGroup: group)
            if let exIndex = workoutDays[dayIndex].exercises?.firstIndex(where: { $0.id == dayExercise.id }) {
                workoutDays[dayIndex].exercises?[exIndex].supersetGroup = group
            }
        } catch {
            errorMessage = "Failed to update superset: \(error.localizedDescription)"
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
