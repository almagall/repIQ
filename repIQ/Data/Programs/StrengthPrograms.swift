import Foundation

enum StrengthPrograms {

    // MARK: - Wendler's 5/3/1

    static let wendler531 = ProgramDefinition(
        id: "wendler-531",
        name: "Wendler's 5/3/1",
        description: "Jim Wendler's proven strength program built around four core lifts with sub-maximal training. Each session focuses on one main lift with prescribed percentages, followed by assistance work. Designed for long-term, sustainable strength gains.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        progressionType: .percentageBased,
        tags: ["proven", "4 days", "submaximal", "long-term"],
        days: [
            ProgramDayDefinition(
                id: "531-ohp", name: "Overhead Press",
                description: "Main lift: Overhead Press with 5/3/1 sets, followed by push and single-leg/core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 progression — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Dips (Chest)", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Push"),
                    ProgramExerciseDefinition(exerciseName: "Chin-Ups", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Hanging Leg Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Core"),
                ]),
            ProgramDayDefinition(
                id: "531-deadlift", name: "Deadlift",
                description: "Main lift: Deadlift with 5/3/1 sets, followed by pull and single-leg/core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 progression — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Single-leg"),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Core"),
                ]),
            ProgramDayDefinition(
                id: "531-bench", name: "Bench Press",
                description: "Main lift: Bench Press with 5/3/1 sets, followed by push and pull assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 progression — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Push"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "531-squat", name: "Squat",
                description: "Main lift: Squat with 5/3/1 sets, followed by leg and core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 progression — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Legs"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Hamstrings"),
                    ProgramExerciseDefinition(exerciseName: "Cable Crunch", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Core"),
                ]),
        ])

    // MARK: - Starting Strength

    static let startingStrength = ProgramDefinition(
        id: "starting-strength",
        name: "Starting Strength",
        description: "Mark Rippetoe's foundational novice program. Three training days alternating between two workouts (A/B), built around the squat, bench, press, deadlift, and power clean. Simple, effective, and proven for building a base of strength.",
        category: .strength,
        difficulty: .beginner,
        daysPerWeek: 3,
        progressionType: .linearProgression,
        tags: ["beginner", "novice", "3 days", "linear progression", "proven"],
        days: [
            ProgramDayDefinition(
                id: "ss-a", name: "Workout A",
                description: "Squat, bench press, and deadlift. The bread and butter of Starting Strength.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — add 10 lbs each session"),
                ]),
            ProgramDayDefinition(
                id: "ss-b", name: "Workout B",
                description: "Squat, overhead press, and power clean. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "3x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Power Clean", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "5x3 — add 5 lbs each session"),
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
        progressionType: .linearProgression,
        tags: ["beginner", "popular", "3 days", "linear progression", "simple"],
        days: [
            ProgramDayDefinition(
                id: "sl-a", name: "Workout A",
                description: "Squat, bench press, and barbell row — 5 sets of 5 reps each.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                ]),
            ProgramDayDefinition(
                id: "sl-b", name: "Workout B",
                description: "Squat, overhead press, and deadlift. Alternate with Workout A.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 — add 5 lbs each session"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — add 10 lbs each session"),
                ]),
        ])

    // MARK: - Texas Method

    static let texasMethod = ProgramDefinition(
        id: "texas-method",
        name: "Texas Method",
        description: "An intermediate strength program using weekly periodization: volume on Monday, recovery on Wednesday, intensity on Friday. Designed for lifters who have exhausted linear novice progression and need a more sophisticated approach.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 3,
        progressionType: .percentageBased,
        tags: ["intermediate", "3 days", "weekly periodization"],
        days: [
            ProgramDayDefinition(
                id: "tx-volume", name: "Volume Day",
                description: "High volume work at ~90% of 5RM to drive adaptation. Monday.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 at 90% of 5RM"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "5x5 at 90% of 5RM"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 1, restSecondsOverride: 300, notes: "1x5"),
                ]),
            ProgramDayDefinition(
                id: "tx-recovery", name: "Recovery Day",
                description: "Light work for active recovery. Wednesday.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 2, restSecondsOverride: 180, notes: "2x5 at 80% of Monday's weight"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "3x5 moderate weight"),
                    ProgramExerciseDefinition(exerciseName: "Chin-Ups", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120, notes: "Bodyweight for reps"),
                    ProgramExerciseDefinition(exerciseName: "Back Extensions", trainingMode: .hypertrophy, targetSets: 3, notes: "Light posterior chain work"),
                ]),
            ProgramDayDefinition(
                id: "tx-intensity", name: "Intensity Day",
                description: "Heavy singles or sets of 5 to set new PRs. Friday.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — new 5RM attempt"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 1, restSecondsOverride: 300, notes: "1x5 — new 5RM attempt"),
                    ProgramExerciseDefinition(exerciseName: "Power Clean", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "5x3"),
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
        progressionType: .percentageBased,
        tags: ["intermediate", "4 days", "tiered", "flexible"],
        days: [
            ProgramDayDefinition(
                id: "gzcl-day1", name: "Squat Day",
                description: "T1 squat with T2 sumo deadlift and T3 leg accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Sumo Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day2", name: "Bench Day",
                description: "T1 bench with T2 close-grip bench and T3 chest/tricep accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Close-Grip Bench Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day3", name: "Deadlift Day",
                description: "T1 deadlift with T2 front squat and T3 posterior chain accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
            ProgramDayDefinition(
                id: "gzcl-day4", name: "Press Day",
                description: "T1 overhead press with T2 incline bench and T3 shoulder/back accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "T1: heavy — 5x3+"),
                    ProgramExerciseDefinition(exerciseName: "Incline Barbell Bench Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120, notes: "T2: moderate — 3x10"),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "T3: light"),
                ]),
        ])

    // MARK: - 5/3/1 Boring But Big

    static let wendler531BBB = ProgramDefinition(
        id: "wendler-531-bbb",
        name: "5/3/1 Boring But Big",
        description: "The most popular 5/3/1 variant by Jim Wendler. After the main 5/3/1 sets, you perform 5 sets of 10 at 50% of the same lift for hypertrophy volume. Builds both strength and size simultaneously over a sustained training block.",
        category: .strength,
        difficulty: .intermediate,
        daysPerWeek: 4,
        progressionType: .percentageBased,
        tags: ["popular", "4 days", "strength + size", "Wendler", "BBB"],
        days: [
            ProgramDayDefinition(
                id: "531bbb-ohp", name: "Overhead Press",
                description: "5/3/1 OHP main sets + BBB 5×10 at 50%, followed by pull and core assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 sets — work to top set"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "BBB: 5×10 at 50% — same lift, lighter weight"),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Dips (Chest)", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Push"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "Shoulder health"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-deadlift", name: "Deadlift",
                description: "5/3/1 Deadlift main sets + BBB 5×10 at 50%, followed by single-leg and core work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "5/3/1 sets — work to top set"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 120, notes: "BBB: 5×10 at 50% — same lift, lighter weight"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 5, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Single-leg"),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Core"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-bench", name: "Bench Press",
                description: "5/3/1 Bench main sets + BBB 5×10 at 50%, followed by row and shoulder assistance.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "5/3/1 sets — work to top set"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "BBB: 5×10 at 50% — same lift, lighter weight"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 90, notes: "Assistance: Pull"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3, notes: "Shoulder health"),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Triceps"),
                ]),
            ProgramDayDefinition(
                id: "531bbb-squat", name: "Squat",
                description: "5/3/1 Squat main sets + BBB 5×10 at 50%, followed by hamstring and core work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "5/3/1 sets — work to top set"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 5, restSecondsOverride: 120, notes: "BBB: 5×10 at 50% — same lift, lighter weight"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Hamstrings"),
                    ProgramExerciseDefinition(exerciseName: "Hanging Leg Raises", trainingMode: .hypertrophy, targetSets: 3, notes: "Assistance: Core"),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4, notes: "Assistance: Calves"),
                ]),
        ])

    // MARK: - nSuns 5/3/1 LP

    static let nsuns = ProgramDefinition(
        id: "nsuns-531",
        name: "nSuns 5/3/1 LP",
        description: "A high-volume linear progression variant of 5/3/1 with 8-9 working sets per main lift and a secondary compound movement. Known for rapid strength gains in intermediate lifters willing to handle the volume.",
        category: .strength,
        difficulty: .advanced,
        daysPerWeek: 5,
        progressionType: .percentageBased,
        tags: ["advanced", "5 days", "high volume", "rapid progression"],
        days: [
            ProgramDayDefinition(
                id: "nsuns-day1", name: "Bench / Close-Grip",
                description: "Primary bench press with close-grip bench as secondary, plus accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 9, restSecondsOverride: 180, notes: "T1: 5/3/1 sets — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Close-Grip Bench Press", trainingMode: .strength, targetSets: 8, restSecondsOverride: 120, notes: "T2: volume sets"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 4, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 4, notes: "Accessory"),
                ]),
            ProgramDayDefinition(
                id: "nsuns-day2", name: "Squat / Sumo Deadlift",
                description: "Primary squat with sumo deadlift as secondary, plus leg accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 9, restSecondsOverride: 180, notes: "T1: 5/3/1 sets — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Sumo Deadlift", trainingMode: .strength, targetSets: 8, restSecondsOverride: 120, notes: "T2: volume sets"),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                ]),
            ProgramDayDefinition(
                id: "nsuns-day3", name: "OHP / Incline Bench",
                description: "Primary overhead press with incline bench as secondary, plus accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 9, restSecondsOverride: 180, notes: "T1: 5/3/1 sets — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Incline Barbell Bench Press", trainingMode: .strength, targetSets: 8, restSecondsOverride: 120, notes: "T2: volume sets"),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Chin-Ups", trainingMode: .hypertrophy, targetSets: 4, notes: "Accessory"),
                ]),
            ProgramDayDefinition(
                id: "nsuns-day4", name: "Deadlift / Front Squat",
                description: "Primary deadlift with front squat as secondary, plus accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 9, restSecondsOverride: 180, notes: "T1: 5/3/1 sets — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .strength, targetSets: 8, restSecondsOverride: 120, notes: "T2: volume sets"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                ]),
            ProgramDayDefinition(
                id: "nsuns-day5", name: "Bench / Overhead Press",
                description: "Second bench day with overhead press as secondary, plus accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 9, restSecondsOverride: 180, notes: "T1: 5/3/1 sets — Phase 2"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 8, restSecondsOverride: 120, notes: "T2: volume sets"),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3, notes: "Accessory"),
                ]),
        ])
}
