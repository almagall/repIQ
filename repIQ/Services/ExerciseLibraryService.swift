import Foundation
import Supabase

struct ExerciseLibraryService: Sendable {
    func fetchExercises(muscleGroup: String? = nil, equipment: String? = nil, searchQuery: String? = nil) async throws -> [Exercise] {
        var query = supabase.from("exercises")
            .select()

        if let muscleGroup {
            query = query.eq("muscle_group", value: muscleGroup)
        }
        if let equipment {
            query = query.eq("equipment", value: equipment)
        }
        if let searchQuery, !searchQuery.isEmpty {
            query = query.ilike("name", pattern: "%\(searchQuery)%")
        }

        let exercises: [Exercise] = try await query
            .order("muscle_group")
            .order("name")
            .execute()
            .value

        return exercises
    }

    func fetchExercise(id: UUID) async throws -> Exercise {
        try await supabase.from("exercises")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    /// Fetches exercise names by their IDs. Returns a dictionary mapping exercise ID → name.
    func fetchExercisesByIds(_ ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let exercises: [Exercise] = try await supabase.from("exercises")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    /// Fetches both name and muscle group for a set of exercise IDs in a single query.
    func fetchExerciseNamesAndMuscleGroups(_ ids: [UUID]) async throws -> (names: [UUID: String], muscleGroups: [UUID: String]) {
        guard !ids.isEmpty else { return ([:], [:]) }
        let exercises: [Exercise] = try await supabase.from("exercises")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        let names = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
        let muscleGroups = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup) })
        return (names, muscleGroups)
    }

    /// Fetches name + muscle group + equipment + isCompound for a batch.
    /// Used by the Strength Trajectory selector to prefer compound lifts.
    func fetchExerciseDetails(_ ids: [UUID]) async throws -> (
        names: [UUID: String],
        muscleGroups: [UUID: String],
        equipment: [UUID: String],
        isCompound: [UUID: Bool]
    ) {
        guard !ids.isEmpty else { return ([:], [:], [:], [:]) }
        let exercises: [Exercise] = try await supabase.from("exercises")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        let names = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
        let muscleGroups = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup) })
        let equipment = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.equipment) })
        let isCompound = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.isCompound) })
        return (names, muscleGroups, equipment, isCompound)
    }

    func createCustomExercise(
        userId: UUID,
        name: String,
        muscleGroup: String,
        equipment: String,
        isCompound: Bool,
        defaultRestSeconds: Int = 90
    ) async throws -> Exercise {
        try await supabase.from("exercises")
            .insert([
                "user_id": userId.uuidString,
                "name": name,
                "muscle_group": muscleGroup,
                "equipment": equipment,
                "is_compound": "\(isCompound)",
                "default_rest_seconds": "\(defaultRestSeconds)"
            ])
            .select()
            .single()
            .execute()
            .value
    }
}
