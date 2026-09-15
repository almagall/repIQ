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

    /// A template the Progress tab can be scoped to: one with a completed
    /// session in the window. Carries its day ids because `progression_log`
    /// is keyed by day, not template.
    struct TemplateScope: Identifiable, Sendable, Equatable {
        let id: UUID
        let name: String
        let lastTrained: Date
        let workoutDayIds: [UUID]
    }

    /// Templates trained in the last `windowDays`, most recently trained first.
    /// A deleted template's sessions keep their id but have no name, so they
    /// drop out here rather than showing as a blank row.
    func fetchTemplatesWithHistory(userId: UUID, windowDays: Int) async throws -> [TemplateScope] {
        guard let since = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) else { return [] }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct SessionRow: Decodable {
            let template_id: String?
            let completed_at: Date?
        }
        let sessions: [SessionRow] = try await supabase.from("workout_sessions")
            .select("template_id,completed_at")
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .not("template_id", operator: .is, value: "null")
            .gte("completed_at", value: iso.string(from: since))
            .order("completed_at", ascending: false)
            .execute()
            .value

        var lastTrained: [UUID: Date] = [:]
        for row in sessions {
            guard let raw = row.template_id, let id = UUID(uuidString: raw), let date = row.completed_at else { continue }
            if lastTrained[id] == nil { lastTrained[id] = date }
        }
        guard !lastTrained.isEmpty else { return [] }

        struct TemplateRow: Decodable {
            let id: UUID
            let name: String
        }
        let templates: [TemplateRow] = try await supabase.from("templates")
            .select("id,name")
            .in("id", values: lastTrained.keys.map(\.uuidString))
            .execute()
            .value

        struct DayRow: Decodable {
            let id: UUID
            let template_id: UUID
        }
        let days: [DayRow] = try await supabase.from("workout_days")
            .select("id,template_id")
            .in("template_id", values: templates.map(\.id.uuidString))
            .execute()
            .value
        let daysByTemplate = Dictionary(grouping: days, by: \.template_id)

        return templates.compactMap { row in
            guard let trained = lastTrained[row.id] else { return nil }
            return TemplateScope(
                id: row.id, name: row.name, lastTrained: trained,
                workoutDayIds: (daysByTemplate[row.id] ?? []).map(\.id)
            )
        }
        .sorted { $0.lastTrained > $1.lastTrained }
    }

    func fetchTemplate(id: UUID) async throws -> Template {
        try await supabase.from("templates")
            .select("*, workout_days(*, workout_day_exercises(*, exercises(*)))")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createTemplate(userId: UUID, name: String, description: String?, sourceProgram: String? = nil) async throws -> Template {
        var fields: [String: String] = [
            "user_id": userId.uuidString,
            "name": name,
            "description": description ?? ""
        ]
        if let sourceProgram {
            fields["source_program"] = sourceProgram
        }
        return try await supabase.from("templates")
            .insert(fields)
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
        setScheme: SetScheme = .ramped,
        progressionRule: ProgressionRule = .autoregulated,
        targetSets: Int,
        sortOrder: Int,
        restSecondsOverride: Int? = nil,
        notes: String? = nil,
        repCap: Int? = nil
    ) async throws -> WorkoutDayExercise {
        struct ExerciseInsert: Encodable {
            let workout_day_id: UUID
            let exercise_id: UUID
            let training_mode: String
            let set_scheme: String
            let progression_rule: String
            let target_sets: Int
            let sort_order: Int
            let rest_seconds_override: Int?
            let notes: String?
            let rep_cap: Int?
        }
        return try await supabase.from("workout_day_exercises")
            .insert(ExerciseInsert(
                workout_day_id: workoutDayId,
                exercise_id: exerciseId,
                training_mode: trainingMode.rawValue,
                set_scheme: setScheme.rawValue,
                progression_rule: progressionRule.rawValue,
                target_sets: targetSets,
                sort_order: sortOrder,
                rest_seconds_override: restSecondsOverride,
                notes: notes,
                rep_cap: repCap
            ))
            .select("*, exercises(*)")
            .single()
            .execute()
            .value
    }

    func updateDayExercise(
        id: UUID,
        trainingMode: TrainingMode,
        setScheme: SetScheme,
        progressionRule: ProgressionRule = .autoregulated,
        targetSets: Int,
        repCap: Int? = nil
    ) async throws {
        struct ExerciseUpdate: Encodable {
            let training_mode: String
            let set_scheme: String
            let progression_rule: String
            let target_sets: Int
            let rep_cap: Int?

            // Synthesized Encodable skips nil keys, which turns "clear the cap"
            // into "leave the cap alone". Encode the null explicitly.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(training_mode, forKey: .training_mode)
                try c.encode(set_scheme, forKey: .set_scheme)
                try c.encode(progression_rule, forKey: .progression_rule)
                try c.encode(target_sets, forKey: .target_sets)
                try c.encode(rep_cap, forKey: .rep_cap)
            }

            enum CodingKeys: String, CodingKey {
                case training_mode, set_scheme, progression_rule, target_sets, rep_cap
            }
        }
        try await supabase.from("workout_day_exercises")
            .update(ExerciseUpdate(
                training_mode: trainingMode.rawValue,
                set_scheme: setScheme.rawValue,
                progression_rule: progressionRule.rawValue,
                target_sets: targetSets,
                rep_cap: repCap
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateSupersetGroup(id: UUID, supersetGroup: Int?) async throws {
        struct SupersetUpdate: Encodable {
            let superset_group: Int?

            // Explicitly encode null instead of skipping the key
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(superset_group, forKey: .superset_group)
            }

            enum CodingKeys: String, CodingKey {
                case superset_group
            }
        }
        try await supabase.from("workout_day_exercises")
            .update(SupersetUpdate(superset_group: supersetGroup))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateDayExerciseSortOrder(id: UUID, sortOrder: Int) async throws {
        try await supabase.from("workout_day_exercises")
            .update(["sort_order": "\(sortOrder)"])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func removeDayExercise(id: UUID) async throws {
        try await supabase.from("workout_day_exercises")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Duplicate Template

    /// Creates a deep copy of a template including all workout days and exercises.
    func duplicateTemplate(templateId: UUID, userId: UUID) async throws -> Template {
        // 1. Fetch the full template with nested data
        let original = try await fetchTemplate(id: templateId)

        // 2. Create new template
        let newTemplate = try await createTemplate(
            userId: userId,
            name: "\(original.name) (Copy)",
            description: original.description,
            sourceProgram: original.sourceProgram
        )

        // 3. Duplicate each workout day and its exercises
        if let days = original.workoutDays {
            for (dayIndex, day) in days.enumerated() {
                let newDay = try await createWorkoutDay(
                    templateId: newTemplate.id,
                    name: day.name,
                    description: day.description,
                    sortOrder: dayIndex
                )

                if let exercises = day.exercises {
                    for (exIndex, exercise) in exercises.enumerated() {
                        let newExercise = try await addExerciseToDay(
                            workoutDayId: newDay.id,
                            exerciseId: exercise.exerciseId,
                            trainingMode: exercise.trainingMode,
                            setScheme: exercise.setScheme,
                            targetSets: exercise.targetSets,
                            sortOrder: exIndex,
                            restSecondsOverride: exercise.restSecondsOverride,
                            notes: exercise.notes,
                            repCap: exercise.repCap
                        )
                        if let group = exercise.supersetGroup {
                            try await updateSupersetGroup(id: newExercise.id, supersetGroup: group)
                        }
                    }
                }
            }
        }

        // 4. Return the full new template
        return try await fetchTemplate(id: newTemplate.id)
    }
}
