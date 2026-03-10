import Foundation

enum HypertrophyPrograms {

    // MARK: - Push Pull Legs (6-Day)

    static let pushPullLegs6Day = ProgramDefinition(
        id: "ppl-6day",
        name: "Push Pull Legs (6-Day)",
        description: "The classic PPL split run twice per week. Each muscle group is trained 2x per week with high volume, making it one of the most popular hypertrophy programs for intermediate to advanced lifters.",
        category: .hypertrophy,
        difficulty: .intermediate,
        daysPerWeek: 6,
        progressionType: .standard,
        tags: ["popular", "high volume", "2x frequency"],
        days: [
            ProgramDayDefinition(
                id: "ppl6-push1", name: "Push A",
                description: "Chest-focused push day with heavy pressing and shoulder/tricep accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl6-pull1", name: "Pull A",
                description: "Back-focused pull day with heavy rows and bicep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl6-legs1", name: "Legs A",
                description: "Quad-focused leg day with squats and accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Cable Crunch", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl6-push2", name: "Push B",
                description: "Shoulder-focused push day with overhead pressing and chest accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Lateral Raise", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Overhead Tricep Extension", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl6-pull2", name: "Pull B",
                description: "Lat-focused pull day with vertical pulling and bicep accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "T-Bar Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Reverse Pec Deck", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Preacher Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl6-legs2", name: "Legs B",
                description: "Hamstring and glute-focused leg day.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Hack Squat", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hip Thrust", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])

    // MARK: - Push Pull Legs (3-Day)

    static let pushPullLegs3Day = ProgramDefinition(
        id: "ppl-3day",
        name: "Push Pull Legs (3-Day)",
        description: "A 3-day PPL split for lifters who can only train 3 times per week. Each session covers one movement pattern with sufficient volume for growth.",
        category: .hypertrophy,
        difficulty: .beginner,
        daysPerWeek: 3,
        progressionType: .standard,
        tags: ["beginner friendly", "3 days", "1x frequency"],
        days: [
            ProgramDayDefinition(
                id: "ppl3-push", name: "Push",
                description: "Chest, shoulders, and triceps in one session.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl3-pull", name: "Pull",
                description: "Back and biceps with a mix of horizontal and vertical pulls.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ppl3-legs", name: "Legs",
                description: "Full lower body session hitting quads, hamstrings, and calves.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])

    // MARK: - Upper Lower (4-Day)

    static let upperLower4Day = ProgramDefinition(
        id: "upper-lower-4day",
        name: "Upper Lower (4-Day)",
        description: "A 4-day upper/lower split hitting each muscle group twice per week. Balances volume and recovery well for most intermediate lifters.",
        category: .hypertrophy,
        difficulty: .intermediate,
        daysPerWeek: 4,
        progressionType: .standard,
        tags: ["balanced", "2x frequency", "4 days"],
        days: [
            ProgramDayDefinition(
                id: "ul4-upper1", name: "Upper A",
                description: "Heavy pressing emphasis with back and arm work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ul4-lower1", name: "Lower A",
                description: "Quad-dominant lower day with hamstring and calf work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Hanging Leg Raises", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ul4-upper2", name: "Upper B",
                description: "Volume upper day with dumbbell and isolation focus.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "ul4-lower2", name: "Lower B",
                description: "Hamstring and glute-focused lower day.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hip Thrust", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])

    // MARK: - Arnold Split (6-Day)

    static let arnoldSplit = ProgramDefinition(
        id: "arnold-split",
        name: "Arnold Split (6-Day)",
        description: "Arnold Schwarzenegger's classic training split pairing chest/back, shoulders/arms, and legs. High volume with antagonist supersets for maximum pump and efficiency.",
        category: .hypertrophy,
        difficulty: .advanced,
        daysPerWeek: 6,
        progressionType: .standard,
        tags: ["classic", "high volume", "advanced", "2x frequency"],
        days: [
            ProgramDayDefinition(
                id: "arnold-cb1", name: "Chest & Back A",
                description: "Heavy chest and back supersets for maximum pump.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "T-Bar Row", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "arnold-sa1", name: "Shoulders & Arms A",
                description: "Overhead pressing with superset arm work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Front Raises", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "arnold-legs1", name: "Legs A",
                description: "Quad-focused leg day with heavy squats.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Cable Crunch", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "arnold-cb2", name: "Chest & Back B",
                description: "Dumbbell-focused chest and back session.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Pec Deck", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "arnold-sa2", name: "Shoulders & Arms B",
                description: "Dumbbell shoulder work with isolation arm exercises.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Cable Lateral Raise", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Reverse Pec Deck", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Preacher Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "arnold-legs2", name: "Legs B",
                description: "Hamstring and glute emphasis with calf work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Hack Squat", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hip Thrust", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])

    // MARK: - Bro Split (5-Day)

    static let broSplit = ProgramDefinition(
        id: "bro-split",
        name: "Bro Split (5-Day)",
        description: "The traditional bodybuilding split dedicating one day per muscle group. High volume per session with a full week of recovery before hitting the same muscle again.",
        category: .hypertrophy,
        difficulty: .intermediate,
        daysPerWeek: 5,
        progressionType: .standard,
        tags: ["bodybuilding", "high volume", "1x frequency"],
        days: [
            ProgramDayDefinition(
                id: "bro-chest", name: "Chest",
                description: "Full chest session with pressing and isolation work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Pec Deck", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Push-Ups", trainingMode: .hypertrophy, targetSets: 3, notes: "Burnout to failure"),
                ]),
            ProgramDayDefinition(
                id: "bro-back", name: "Back",
                description: "Complete back development from lats to traps.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "bro-shoulders", name: "Shoulders",
                description: "All three delt heads with heavy pressing and isolation work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Cable Lateral Raise", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Reverse Pec Deck", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Front Raises", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "bro-legs", name: "Legs",
                description: "Complete lower body session from quads to calves.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
            ProgramDayDefinition(
                id: "bro-arms", name: "Arms",
                description: "Dedicated arm day with superset bicep and tricep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Preacher Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Overhead Tricep Extension", trainingMode: .hypertrophy, targetSets: 3),
                ]),
        ])

    // MARK: - Full Body (3-Day)

    static let fullBody3Day = ProgramDefinition(
        id: "full-body-3day",
        name: "Full Body (3-Day)",
        description: "Three full-body sessions per week, each hitting all major muscle groups. Ideal for beginners or lifters with limited training time who still want full-body coverage.",
        category: .hypertrophy,
        difficulty: .beginner,
        daysPerWeek: 3,
        progressionType: .standard,
        tags: ["beginner friendly", "3 days", "3x frequency", "efficient"],
        days: [
            ProgramDayDefinition(
                id: "fb3-day1", name: "Full Body A",
                description: "Squat and bench emphasis with balanced accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 2),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 2),
                ]),
            ProgramDayDefinition(
                id: "fb3-day2", name: "Full Body B",
                description: "Deadlift and overhead press emphasis.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "fb3-day3", name: "Full Body C",
                description: "Leg press and dumbbell pressing focus.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 2),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 2),
                ]),
        ])
}
