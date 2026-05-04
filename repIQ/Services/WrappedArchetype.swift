import Foundation

/// One-of-five training "personality" labels surfaced on the closing slide
/// of the monthly wrapped. Deterministic — no AI in this tier. Ordering
/// matters: the classifier walks the list in order and the first match wins,
/// so put the more specific/aspirational labels first and the catch-all
/// (`steadyBuilder`) last.
enum WrappedArchetype: String, Codable, Sendable, CaseIterable {
    case prHunter
    case volumeHammer
    case consistencyKing
    case varietySeeker
    case steadyBuilder

    var displayName: String {
        switch self {
        case .prHunter:        return "PR Hunter"
        case .volumeHammer:    return "Volume Hammer"
        case .consistencyKing: return "Consistency King"
        case .varietySeeker:   return "Variety Seeker"
        case .steadyBuilder:   return "Steady Builder"
        }
    }

    var headline: String {
        switch self {
        case .prHunter:        return "You came to break records."
        case .volumeHammer:    return "You came to put in work."
        case .consistencyKing: return "You came to show up — every time."
        case .varietySeeker:   return "You came to explore."
        case .steadyBuilder:   return "Brick by brick. That's how it's built."
        }
    }

    var systemImageName: String {
        switch self {
        case .prHunter:        return "trophy.fill"
        case .volumeHammer:    return "hammer.fill"
        case .consistencyKing: return "calendar.badge.checkmark"
        case .varietySeeker:   return "shuffle.circle.fill"
        case .steadyBuilder:   return "square.stack.3d.up.fill"
        }
    }

    /// Inputs the classifier needs. Kept as a tiny struct so the call site
    /// (DigestService) can build it once and pass it in, and so the rules
    /// are easy to test without spinning up a Supabase client.
    struct Inputs {
        let totalSessions: Int
        let totalPRs: Int
        let totalVolume: Double
        let longestStreak: Int
        /// Average distinct exercises per session in the month.
        let avgUniqueExercisesPerSession: Double
    }

    static func classify(_ input: Inputs) -> WrappedArchetype {
        // PR Hunter — strong PR rate. Threshold: at least 3 PRs AND PRs ≥ 1/4
        // of sessions. This rules out single-PR months as the dominant story.
        if input.totalPRs >= 3,
           Double(input.totalPRs) >= Double(max(input.totalSessions, 1)) / 4.0 {
            return .prHunter
        }

        // Volume Hammer — very high volume per session. 15k lbs/session is a
        // genuine grinder; below that is normal training.
        if input.totalSessions > 0,
           input.totalVolume / Double(input.totalSessions) > 15_000 {
            return .volumeHammer
        }

        // Consistency King — either a 14-day streak, or 16+ sessions in a month
        // (≈ 4×/week average).
        if input.longestStreak >= 14 || input.totalSessions >= 16 {
            return .consistencyKing
        }

        // Variety Seeker — broad exercise pool per session.
        if input.avgUniqueExercisesPerSession >= 5 {
            return .varietySeeker
        }

        return .steadyBuilder
    }
}
