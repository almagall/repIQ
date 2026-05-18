import Foundation
import SwiftUI

/// Strength classification tiers based on bodyweight-multiple thresholds for
/// the main compound lifts. Values are intermediate-level reference numbers
/// drawn from commonly cited strength tables (ExRx + Lon Kilgore consensus).
/// Treats the standards as 1RM thresholds, compared against e1RM from logs.
enum StrengthStandards {

    /// Coarse movement categories the standards table covers. Mapped to the
    /// user's exercise name via `category(forExerciseName:)`.
    enum Category: String, CaseIterable {
        case squat
        case bench
        case deadlift
        case overheadPress
        case row

        var displayName: String {
            switch self {
            case .squat: return "Squat"
            case .bench: return "Bench"
            case .deadlift: return "Deadlift"
            case .overheadPress: return "Overhead Press"
            case .row: return "Row"
            }
        }
    }

    /// Strength tier the user falls into for a given lift. Each tier name
    /// reflects the conventional terminology used in strength-training
    /// literature.
    enum Tier: Int, CaseIterable {
        case untrained = 0
        case novice = 1
        case intermediate = 2
        case advanced = 3
        case elite = 4

        var displayName: String {
            switch self {
            case .untrained: return "Untrained"
            case .novice: return "Novice"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            case .elite: return "Elite"
            }
        }

        var color: Color {
            switch self {
            case .untrained: return RQColors.textTertiary
            case .novice: return RQColors.textSecondary
            case .intermediate: return RQColors.info
            case .advanced: return RQColors.success
            case .elite: return RQColors.warning
            }
        }

        /// Approximate percentile band relative to a population of trained
        /// lifters. Used for the chip caption.
        var percentileLabel: String {
            switch self {
            case .untrained: return "Bottom 20%"
            case .novice: return "20–50%"
            case .intermediate: return "50–80%"
            case .advanced: return "80–95%"
            case .elite: return "Top 5%"
            }
        }
    }

    /// Bodyweight multiples per (category, sex) for the tier boundaries.
    /// Reading: a male intermediate squatter benches at least 1.0× bodyweight;
    /// advanced is 1.5×, elite is 2.0×, etc.
    private static let maleThresholds: [Category: [Double]] = [
        // [novice, intermediate, advanced, elite]
        .squat:         [1.0, 1.5, 2.25, 2.75],
        .bench:         [0.75, 1.0, 1.5, 2.0],
        .deadlift:      [1.25, 1.75, 2.5, 3.0],
        .overheadPress: [0.5, 0.75, 1.0, 1.4],
        .row:           [0.75, 1.0, 1.4, 1.75]
    ]

    private static let femaleThresholds: [Category: [Double]] = [
        .squat:         [0.75, 1.1, 1.6, 2.0],
        .bench:         [0.5, 0.75, 1.0, 1.4],
        .deadlift:      [1.0, 1.4, 1.9, 2.4],
        .overheadPress: [0.35, 0.55, 0.75, 1.0],
        .row:           [0.5, 0.75, 1.0, 1.4]
    ]

    /// Maps a user-visible exercise name to a category. Matching is by
    /// lowercased keyword so variations ("Barbell Back Squat", "Front Squat",
    /// "DB Bench") all resolve when their keyword is present.
    static func category(forExerciseName name: String) -> Category? {
        let lower = name.lowercased()
        if lower.contains("deadlift") { return .deadlift }
        if lower.contains("squat") { return .squat }
        if lower.contains("bench") { return .bench }
        if lower.contains("overhead press") || lower.contains("ohp") || lower.contains("military press") || lower.contains("shoulder press") {
            return .overheadPress
        }
        if lower.contains("row") { return .row }
        return nil
    }

    /// Returns the user's tier for a given lift, or nil when the exercise
    /// doesn't map to a covered category or bodyweight is unknown.
    /// `bodyweightLbs` is the user's bodyweight in pounds; pass the
    /// profile's `bodyWeightKg * 2.20462` if your unit is kg.
    static func classify(
        exerciseName: String,
        e1RM: Double,
        bodyweightLbs: Double,
        sex: String?
    ) -> (category: Category, tier: Tier, ratio: Double)? {
        guard bodyweightLbs > 0,
              let category = category(forExerciseName: exerciseName),
              e1RM > 0 else { return nil }

        let thresholds = (sex?.lowercased() == "female" ? femaleThresholds : maleThresholds)[category] ?? []
        guard thresholds.count == 4 else { return nil }

        let ratio = e1RM / bodyweightLbs

        let tier: Tier
        if ratio >= thresholds[3] { tier = .elite }
        else if ratio >= thresholds[2] { tier = .advanced }
        else if ratio >= thresholds[1] { tier = .intermediate }
        else if ratio >= thresholds[0] { tier = .novice }
        else { tier = .untrained }

        return (category, tier, ratio)
    }

    /// The next threshold the user is working toward, in lbs. Returns nil
    /// when the user is already at elite tier.
    static func nextThreshold(category: Category, tier: Tier, bodyweightLbs: Double, sex: String?) -> Double? {
        guard tier != .elite, bodyweightLbs > 0 else { return nil }
        let thresholds = (sex?.lowercased() == "female" ? femaleThresholds : maleThresholds)[category] ?? []
        let nextIndex = tier.rawValue // 0 → novice idx 0; 1 → intermediate idx 1; ...
        guard nextIndex < thresholds.count else { return nil }
        return thresholds[nextIndex] * bodyweightLbs
    }
}
