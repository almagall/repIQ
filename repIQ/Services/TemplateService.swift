import Foundation
import Supabase

struct TemplateService: Sendable {

    // MARK: - Templates

    func fetchTemplates(userId: UUID) async throws -> [Template] {
        try await supabase.from("templates")
            .select("*, workout_days(*, workout_day_exercises(*, exercises(*)))")
            .eq("user_id", value: userId.uuidString)
            .order("sort_order")
            .execute()
            .value
    }

    func fetchTemplate(id: UUID) async throws -> Template {
        try await supabase.from("templates")
            .select("*, workout_days(*, workout_day_exercises(*, exercises(*)))")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createTemplate(userId: UUID, name: String, description: String?) async throws -> Template {
        try await supabase.from("templates")
            .insert([
                "user_id": userId.uuidString,
                "name": name,
                "description": description ?? ""
            ])
            .select()
            .single()
            .execute()
            .value
    }

    func updateTemplate(id: UUID, name: String, description: String?) async throws {
        try await supabase.from("templates")
            .update([
                "name": name,
                "description": description ?? "",
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteTemplate(id: UUID) async throws {
        try await supabase.from("templates")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Workout Days

    func createWorkoutDay(templateId: UUID, name: String, description: String?, sortOrder: Int) async throws -> WorkoutDay {
        try await supabase.from("workout_days")
            .insert([
                "template_id": templateId.uuidString,
                "name": name,
                "description": description ?? "",
                "sort_order": "\(sortOrder)"
            ])
            .select()
            .single()
            .execute()
            .value
    }

    func updateWorkoutDay(id: UUID, name: String, description: String?) async throws {
        try await supabase.from("workout_days")
            .update([
                "name": name,
                "description": description ?? ""
            ])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteWorkoutDay(id: UUID) async throws {
        try await supabase.from("workout_days")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Workout Day Exercises

    func addExerciseToDay(
        workoutDayId: UUID,
        exerciseId: UUID,
        trainingMode: TrainingMode,
        targetSets: Int,
        sortOrder: Int
    ) async throws -> WorkoutDayExercise {
        try await supabase.from("workout_day_exercises")
            .insert([
                "workout_day_id": workoutDayId.uuidString,
                "exercise_id": exerciseId.uuidString,
                "training_mode": trainingMode.rawValue,
                "target_sets": "\(targetSets)",
                "sort_order": "\(sortOrder)"
            ])
            .select("*, exercises(*)")
            .single()
            .execute()
            .value
    }

    func updateDayExercise(id: UUID, trainingMode: TrainingMode, targetSets: Int) async throws {
        try await supabase.from("workout_day_exercises")
            .update([
                "training_mode": trainingMode.rawValue,
                "target_sets": "\(targetSets)"
            ])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func removeDayExercise(id: UUID) async throws {
        try await supabase.from("workout_day_exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
