import Foundation

enum HybridPrograms {

    // MARK: - PHUL (Power Hypertrophy Upper Lower)

    static let phul = ProgramDefinition(
        id: "phul",
        name: "PHUL",
        description: "Power Hypertrophy Upper Lower combines heavy compound work for strength with higher-rep hypertrophy sessions. Each muscle group is hit twice per week — once with heavy weight and once with moderate weight for volume.",
        category: .hybrid,
        difficulty: .intermediate,
        daysPerWeek: 4,
        progressionType: .standard,
        tags: ["popular", "4 days", "2x frequency", "balanced"],
        days: [
            ProgramDayDefinition(
                id: "phul-up", name: "Upper Power",
                description: "Heavy compound pressing and pulling for upper body strength.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phul-lp", name: "Lower Power",
                description: "Heavy squats and deadlifts for lower body strength.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 4, restSecondsOverride: 300),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .strength, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
            ProgramDayDefinition(
                id: "phul-uh", name: "Upper Hypertrophy",
                description: "Moderate weight, higher reps for upper body muscle growth.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Overhead Tricep Extension", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phul-lh", name: "Lower Hypertrophy",
                description: "Moderate weight, higher reps for lower body muscle growth.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])

    // MARK: - PHAT (Power Hypertrophy Adaptive Training)

    static let phat = ProgramDefinition(
        id: "phat",
        name: "PHAT",
        description: "Layne Norton's Power Hypertrophy Adaptive Training is a 5-day program combining two power days with three hypertrophy days. Designed for experienced lifters who want both strength and size without compromising either.",
        category: .hybrid,
        difficulty: .advanced,
        daysPerWeek: 5,
        progressionType: .standard,
        tags: ["advanced", "5 days", "high volume", "Layne Norton"],
        days: [
            ProgramDayDefinition(
                id: "phat-up", name: "Upper Power",
                description: "Heavy upper body compounds for strength development.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Rack Pull", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 4, restSecondsOverride: 180),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phat-lp", name: "Lower Power",
                description: "Heavy lower body compounds for strength development.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 4, restSecondsOverride: 300),
                    ProgramExerciseDefinition(exerciseName: "Hack Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Stiff-Leg Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phat-bsh", name: "Back & Shoulders Hypertrophy",
                description: "High rep back and shoulder work for size.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Shoulder Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Cable Lateral Raise", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phat-lh", name: "Legs Hypertrophy",
                description: "High rep leg work for size, emphasizing all angles.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Lunges", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hip Thrust", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "phat-cah", name: "Chest & Arms Hypertrophy",
                description: "High rep chest, bicep, and tricep work for size.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 90),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Preacher Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Overhead Tricep Extension", trainingMode: .hypertrophy, targetSets: 3),
                ]),
        ])

    // MARK: - Conjugate (Westside Barbell)

    static let conjugate = ProgramDefinition(
        id: "conjugate",
        name: "Conjugate Method",
        description: "Based on Westside Barbell's system, the conjugate method uses max effort and dynamic effort days for both upper and lower body. Trains maximal strength, speed-strength, and repetition effort across four sessions per week.",
        category: .hybrid,
        difficulty: .advanced,
        daysPerWeek: 4,
        progressionType: .standard,
        tags: ["advanced", "4 days", "Westside", "speed work"],
        days: [
            ProgramDayDefinition(
                id: "conj-meu", name: "Max Effort Upper",
                description: "Work up to a heavy single, double, or triple on a pressing variation, followed by accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "Work up to heavy single/triple"),
                    ProgramExerciseDefinition(exerciseName: "Close-Grip Bench Press", trainingMode: .hypertrophy, targetSets: 4, restSecondsOverride: 120, notes: "Supplemental volume"),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "conj-mel", name: "Max Effort Lower",
                description: "Work up to a heavy single, double, or triple on a squat or deadlift variation.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 5, restSecondsOverride: 300, notes: "Work up to heavy single/triple"),
                    ProgramExerciseDefinition(exerciseName: "Good Mornings", trainingMode: .strength, targetSets: 4, restSecondsOverride: 120, notes: "Supplemental posterior chain"),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Ab Wheel Rollout", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "conj-deu", name: "Dynamic Effort Upper",
                description: "Fast, explosive pressing at 50-60% 1RM with short rest, followed by hypertrophy work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 9, restSecondsOverride: 60, notes: "9x3 at 50-60% — focus on bar speed"),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "conj-del", name: "Dynamic Effort Lower",
                description: "Fast, explosive squats at 50-60% 1RM with short rest, followed by hypertrophy work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Box Squat", trainingMode: .strength, targetSets: 12, restSecondsOverride: 60, notes: "12x2 at 50-60% — focus on explosiveness"),
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 120, notes: "Speed pulls — 3x1 at 60-70%"),
                    ProgramExerciseDefinition(exerciseName: "Hip Thrust", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 3),
                ]),
        ])

    // MARK: - Reddit PPL

    static let redditPPL = ProgramDefinition(
        id: "reddit-ppl",
        name: "Reddit PPL (Metallicadpa)",
        description: "The popular Reddit PPL program by Metallicadpa. A 6-day push/pull/legs split that starts each session with a heavy compound lift for strength, followed by hypertrophy accessories. Great for intermediates wanting both strength and size.",
        category: .hybrid,
        difficulty: .intermediate,
        daysPerWeek: 6,
        progressionType: .standard,
        tags: ["popular", "6 days", "2x frequency", "Reddit"],
        days: [
            ProgramDayDefinition(
                id: "rppl-push1", name: "Push A",
                description: "Heavy bench press followed by hypertrophy pressing and shoulder/tricep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "5x5 — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Incline Dumbbell Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Overhead Tricep Extension", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "rppl-pull1", name: "Pull A",
                description: "Heavy deadlift followed by hypertrophy back and bicep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Deadlift", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "1x5+ — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Lat Pulldown", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Cable Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Barbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Hammer Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "rppl-legs1", name: "Legs A",
                description: "Heavy squat followed by hypertrophy leg work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 300, notes: "2x5, 1x5+ — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Romanian Deadlift", trainingMode: .hypertrophy, targetSets: 3, restSecondsOverride: 120),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Standing Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
            ProgramDayDefinition(
                id: "rppl-push2", name: "Push B",
                description: "Heavy overhead press followed by hypertrophy chest and tricep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Overhead Press", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "5x5 — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Barbell Bench Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Bench Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Cable Flyes", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Lateral Raises", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Skull Crushers", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Tricep Pushdown", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "rppl-pull2", name: "Pull B",
                description: "Heavy barbell row followed by hypertrophy back and bicep work.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Barbell Row", trainingMode: .strength, targetSets: 5, restSecondsOverride: 180, notes: "5x5 — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Pull-Ups", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "T-Bar Row", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Face Pulls", trainingMode: .hypertrophy, targetSets: 4),
                    ProgramExerciseDefinition(exerciseName: "Dumbbell Curl", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Preacher Curl", trainingMode: .hypertrophy, targetSets: 3),
                ]),
            ProgramDayDefinition(
                id: "rppl-legs2", name: "Legs B",
                description: "Front squat focus with hypertrophy leg accessories.",
                exercises: [
                    ProgramExerciseDefinition(exerciseName: "Front Squat", trainingMode: .strength, targetSets: 3, restSecondsOverride: 180, notes: "3x5 — strength focus"),
                    ProgramExerciseDefinition(exerciseName: "Bulgarian Split Squat", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Press", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Extensions", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Leg Curls", trainingMode: .hypertrophy, targetSets: 3),
                    ProgramExerciseDefinition(exerciseName: "Seated Calf Raise", trainingMode: .hypertrophy, targetSets: 4),
                ]),
        ])
}
