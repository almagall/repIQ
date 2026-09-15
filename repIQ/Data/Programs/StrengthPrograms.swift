import Foundation

// Only programs the app can run honestly belong here. 5/3/1 runs on its own
// rule (`ProgressionRule.wave531`: a training max and a four-session wave).
// Other percentage cycles (nSuns), cross-day dependencies (Texas Method) and
// max-effort / speed work (Conjugate) still have no representation and stay
// out rather than ship under a name that promises a scheme the app doesn't follow.
enum StrengthPrograms {

    private static let mainLiftNote = "5/3/1 — three sets from your training max; the last is as many as you can. The TM moves when the cycle ends."
    private static let bbbNote = "BBB: 5×10 — starts near 50% of that lift's training max; weight goes up when you get all 50."

    // MARK: - Wendler's 5/3/1

    static let wendler531 = ProgramDefinition(
        id: "wendler-531",
        name: "Wendler's 5/3/1",
        description: "Jim Wendler's submaximal strength program. Each day is one main lift — press, deadlift, bench, squat — run as three sets at percentages of a training max (90% of your 1RM), with the last set taken for as many reps as you can. Four sessions per lift make a cycle: 5s, 3s, 5/3/1, deload; then the training max goes up. Assistance work follows the engine.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        tags: ["proven", "4 days", "submaximal", "training max", "long-term"],
        days: [
            ProgramDayDefinition(
                id: "531-ohp", name: "Overhead Press",
                description: "5/3/1 press, then push, pull and core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 180, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Dips (Chest)", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: push"),
                    ProgramExerciseDefinition(exerciseName: "Chin-Ups", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Hanging Leg Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: core"),
                ]),
            ProgramDayDefinition(
                id: "531-deadlift", name: "Deadlift",
                description: "5/3/1 deadlift, then pull, single-leg and core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 300, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: single-leg"),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: core"),
                ]),
            ProgramDayDefinition(
                id: "531-bench", name: "Bench Press",
                description: "5/3/1 bench, then push and pull assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 180, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: push"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "Shoulder health"),
                ]),
            ProgramDayDefinition(
                id: "531-squat", name: "Squat",
                description: "5/3/1 squat, then leg and core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 300, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: legs"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: hamstrings"),
                    ProgramExerciseDefinition(exerciseName: "Cable Crunch", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: core"),
                ]),
        ])

    // MARK: - 5/3/1 Boring But Big

    // The opposite-lift variant (press day carries bench volume and vice
    // versa, squat and deadlift likewise). The same-lift version would put
    // one exercise on a day twice, and history and targets are keyed by
    // exercise per day, so the two entries would share one prescription.
    static let wendler531BBB = ProgramDefinition(
        id: "wendler-531-bbb",
        name: "5/3/1 Boring But Big",
        description: "The most popular 5/3/1 template. The main lift runs the 5/3/1 wave; then five sets of ten on the opposite lift — bench on press day, press on bench day, squat on deadlift day, deadlift on squat day — starting near 50% of that lift's training max and climbing as you earn all fifty reps. Strength and size in the same block.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        tags: ["popular", "4 days", "strength + size", "Wendler", "BBB"],
        days: [
            ProgramDayDefinition(
                id: "531bbb-ohp", name: "Overhead Press",
                description: "5/3/1 press, BBB bench 5×10, then pull and shoulder-health work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 180, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, setScheme: .straight, targetSets: 5, repCap: 10, restSecondsOverride: 90, notes: bbbNote),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "Shoulder health"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-deadlift", name: "Deadlift",
                description: "5/3/1 deadlift, BBB squat 5×10, then pull and core work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 300, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, setScheme: .straight, targetSets: 5, repCap: 10, restSecondsOverride: 120, notes: bbbNote),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: core"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-bench", name: "Bench Press",
                description: "5/3/1 bench, BBB press 5×10, then row and triceps work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 180, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, setScheme: .straight, targetSets: 5, repCap: 10, restSecondsOverride: 90, notes: bbbNote),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "Assistance: pull"),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: triceps"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-squat", name: "Squat",
                description: "5/3/1 squat, BBB deadlift 5×10, then hamstring and core work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, progressionRule: .wave531, targetSets: 3, restSecondsOverride: 300, notes: mainLiftNote),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .hypertrophy, setScheme: .straight, targetSets: 5, repCap: 10, restSecondsOverride: 120, notes: bbbNote),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: hamstrings"),
                    ProgramExerciseDefinition(exerciseName: "Hanging Leg Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: core"),
                ]),
        ])

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
