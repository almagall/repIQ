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
        // Strength (6)
        StrengthPrograms.wendler531,
        StrengthPrograms.startingStrength,
        StrengthPrograms.strongLifts5x5,
        StrengthPrograms.texasMethod,
        StrengthPrograms.gzclMethod,
        StrengthPrograms.nsuns,
        // Hybrid (4)
        HybridPrograms.phul,
        HybridPrograms.phat,
        HybridPrograms.conjugate,
        HybridPrograms.redditPPL,
    ]

    static func program(for id: String) -> ProgramDefinition? {
        allPrograms.first { $0.id == id }
    }

    static func programs(in category: ProgramCategory) -> [ProgramDefinition] {
        allPrograms.filter { $0.category == category }
    }
}
