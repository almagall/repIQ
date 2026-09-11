import Foundation

enum StrengthPrograms {

    // MARK: - Starting Strength

    static let startingStrength = ProgramDefinition(
        id: "starting-strength",
        name: "Starting Strength",
        description: "Mark Rippetoe's foundational novice program. Three training days alternating between two workouts (A/B), built around the squat, bench, press, deadlift, and power clean. Simple, effective, and proven for building a base of strength.",
        category: .strength,
        difficulty: .beginner,
        daysPerWeek: 3,
        tags: ["beginner", "novice", "3 days", "linear progression", "proven"],
        days: [
            ProgramDayDefinition(
                id: "ss-a", name: "Workout A",
                description: "Squat, bench press, and deadlift. The bread and butter of Starting Strength.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — add 10 lbs each session"),
                ]),
            ProgramDayDefinition(
                id: "ss-b", name: "Workout B",
                description: "Squat, overhead press, and power clean. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Power Clean", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "5x3 — add 5 lbs each session"),
                ]),
        ])

    // MARK: - StrongLifts 5x5

    static let strongLifts5x5 = ProgramDefinition(
        id: "stronglifts-5x5",
        name: "StrongLifts 5x5",
        description: "One of the most popular beginner strength programs. Two alternating workouts (A/B) using just five barbell exercises. Add 5 lbs every session for simple, reliable linear progression.",
        category: .strength,
        difficulty: .beginner,
        daysPerWeek: 3,
        tags: ["beginner", "popular", "3 days", "linear progression", "simple"],
        days: [
            ProgramDayDefinition(
                id: "sl-a", name: "Workout A",
                description: "Squat, bench press, and barbell row — 5 sets of 5 reps each.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                ]),
            ProgramDayDefinition(
                id: "sl-b", name: "Workout B",
                description: "Squat, overhead press, and deadlift. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — add 10 lbs each session"),
                ]),
        ])

    // MARK: - GZCL Method

    static let gzclMethod = ProgramDefinition(
        id: "gzcl-method",
        name: "GZCL Method",
        description: "Cody Lefever's tiered training system. T1 lifts are heavy (85-100% intensity), T2 lifts are moderate (65-85%), and T3 lifts are light isolation work. A flexible, proven framework for building strength with balanced development.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        tags: ["intermediate", "4 days", "tiered", "flexible"],
        days: [
            ProgramDayDefinition(
                id: "gzcl-day1", name: "Squat Day",
                description: "T1 squat with T2 sumo deadlift and T3 leg accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Sumo Deadlift", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day2", name: "Bench Day",
                description: "T1 bench with T2 close-grip bench and T3 chest/tricep accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Close-Grip Bench Press", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day3", name: "Deadlift Day",
                description: "T1 deadlift with T2 front squat and T3 posterior chain accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day4", name: "Press Day",
                description: "T1 overhead press with T2 incline bench and T3 shoulder/back accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Incline Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
        ])
}
