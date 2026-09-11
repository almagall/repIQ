import Foundation

enum ProgramCatalog {
    static let allPrograms: [ProgramDefinition] = [
        // Hypertrophy (6)
        HypertrophyPrograms.pushPullLegs6Day,
        HypertrophyPrograms.pushPullLegs3Day,
        HypertrophyPrograms.upperLower4Day,
        HypertrophyPrograms.arnoldSplit,
        HypertrophyPrograms.broSplit,
        HypertrophyPrograms.fullBody3Day,
        // Strength (3). Programs whose identity is a training-max /
        // percentage / wave scheme (5/3/1 and its variants, Texas Method,
        // Conjugate) are deliberately absent: the engine has no such layer,
        // so materializing them would only reproduce the exercise list.
        StrengthPrograms.startingStrength,
        StrengthPrograms.strongLifts5x5,
        StrengthPrograms.gzclMethod,
        // Hybrid (3)
        HybridPrograms.phul,
        HybridPrograms.phat,
        HybridPrograms.redditPPL,
    ]

    static func program(for id: String) -> ProgramDefinition? {
        allPrograms.first { $0.id == id }
    }

    static func programs(in category: ProgramCategory) -> [ProgramDefinition] {
        allPrograms.filter { $0.category == category }
    }
}
