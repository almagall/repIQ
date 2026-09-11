import Foundation

// Only programs the engine can run honestly belong here. Percentage-of-training-max
// cycles (5/3/1, nSuns), cross-day dependencies (Texas Method) and max-effort /
// speed work (Conjugate) have no representation in the engine and were removed
// rather than shipped under a name that promises a scheme the app doesn't follow.
enum StrengthPrograms {

    // MARK: - Starting Strength

    static let startingStrength = ProgramDefinition(
        id: "starting-strength",
        name: "Starting Strength",
        description: "Mark Rippetoe's foundational novice program. Three training days alternating between two workouts (A/B), built around the squat, bench, press, deadlift, and power clean. Straight sets at one weight; get every rep and the weight goes up next session.",
        category: .strength,
        difficulty: .beginner,
        daysPerWeek: 3,
        tags: ["beginner", "novice", "3 days", "linear progression", "proven"],
        days: [
            ProgramDayDefinition(
                id: "ss-a", name: "Workout A",
                description: "Squat, bench press, and deadlift. The bread and butter of Starting Strength.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "Straight 5s — get every rep and the weight goes up next session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "Straight 5s — get every rep and the weight goes up next session"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 1, restSecondsOverride: 300, notes: "One heavy set of 5 — warm up to it first"),
                ]),
            ProgramDayDefinition(
                id: "ss-b", name: "Workout B",
                description: "Squat, overhead press, and power clean. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "Straight 5s — get every rep and the weight goes up next session"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 3, restSecondsOverride: 300, notes: "Straight 5s — get every rep and the weight goes up next session"),
                    ProgramExerciseDefinition(exerciseName: "Power Clean", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "Straight triples — crisp, explosive reps"),
                ]),
        ])

    // MARK: - StrongLifts 5x5

    static let strongLifts5x5 = ProgramDefinition(
        id: "stronglifts-5x5",
        name: "StrongLifts 5x5",
        description: "One of the most popular beginner strength programs. Two alternating workouts (A/B) using just five barbell exercises. Five straight sets of five at one weight; hit all 25 reps and the weight goes up next session.",
        category: .strength,
        difficulty: .beginner,
        daysPerWeek: 3,
        tags: ["beginner", "popular", "3 days", "linear progression", "simple"],
        days: [
            ProgramDayDefinition(
                id: "sl-a", name: "Workout A",
                description: "Squat, bench press, and barbell row — 5 sets of 5 reps each.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — same weight every set, weight goes up once you get all 25"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — same weight every set, weight goes up once you get all 25"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — same weight every set, weight goes up once you get all 25"),
                ]),
            ProgramDayDefinition(
                id: "sl-b", name: "Workout B",
                description: "Squat, overhead press, and deadlift. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — same weight every set, weight goes up once you get all 25"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — same weight every set, weight goes up once you get all 25"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 1, restSecondsOverride: 300, notes: "One heavy set of 5 — warm up to it first"),
                ]),
        ])

    // MARK: - GZCL Method

    static let gzclMethod = ProgramDefinition(
        id: "gzcl-method",
        name: "GZCL Method",
        description: "Cody Lefever's tiered training system. T1 is the main lift in heavy straight triples, T2 is a related compound in sets of ten, and T3 is light isolation work for high reps. A flexible, proven framework for building strength with balanced development.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        tags: ["intermediate", "4 days", "tiered", "flexible"],
        days: [
            ProgramDayDefinition(
                id: "gzcl-day1", name: "Squat Day",
                description: "T1 squat with T2 sumo deadlift and T3 leg accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy straight triples"),
                    ProgramExerciseDefinition(exerciseName: "Sumo Deadlift", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — sets of 10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day2", name: "Bench Day",
                description: "T1 bench with T2 close-grip bench and T3 chest/tricep accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy straight triples"),
                    ProgramExerciseDefinition(exerciseName: "Close-Grip Bench Press", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — sets of 10"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day3", name: "Deadlift Day",
                description: "T1 deadlift with T2 front squat and T3 posterior chain accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy straight triples"),
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — sets of 10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day4", name: "Press Day",
                description: "T1 overhead press with T2 incline bench and T3 shoulder/back accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, setScheme: .straight, targetSets: 5, repCap: 3, restSecondsOverride: 180, notes: "T1: heavy straight triples"),
                    ProgramExerciseDefinition(exerciseName: "Incline Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, repCap: 10, restSecondsOverride: 120, notes: "T2: moderate — sets of 10"),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light, high reps"),
                ]),
        ])
}
