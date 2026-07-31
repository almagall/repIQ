import SwiftUI

enum RQColors {
    // Primary - Electric Blue accent
    static let accent = Color(hex: "00AAFF")
    static let accentLight = Color(hex: "33BBFF")
    static let accentDark = Color(hex: "0088CC")

    // Backgrounds - near-black, biased a few points toward the accent's hue so
    // #00AAFF reads as part of the page rather than floating above it. A truly
    // neutral ground makes the accent look pasted on.
    static let background = Color(hex: "05080C")
    static let surfacePrimary = Color(hex: "0A0F16")
    static let surfaceSecondary = Color(hex: "131A23")
    static let surfaceTertiary = Color(hex: "1C2430")

    // Structure - the 1px rules the flow layout is built on. Distinct from the
    // text ramp: a border is not disabled text and should not borrow its value.
    static let hairline = Color(hex: "1E2732")

    // Text - carries the same hue bias as the surfaces
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "8A93A1")
    static let textTertiary = Color(hex: "565E6B")

    // Progression state - the vocabulary behind StrengthTrend. Deliberately not
    // the semantic set below: a deload is a plan, not an error, and holding a
    // weight to bank reps is not a warning.
    static let stateAdvancing = Color(hex: "2FD48A")
    static let stateHolding = Color(hex: "E0A93B")
    static let stateBacking = Color(hex: "FF5C5C")

    // Semantic - reserved for actual confirmations, alerts and failures
    static let success = Color(hex: "00CC66")
    static let warning = Color(hex: "FF9500")
    static let error = Color(hex: "FF3B30")
    static let info = Color(hex: "5AC8FA")

    // Superset
    static let supersetGold = Color(hex: "FFD700")

    // Training Modes
    static let hypertrophy = Color(hex: "9B59B6")
    static let strength = Color(hex: "FF6B35")

    // Set Types
    static let warmup = Color(hex: "FF9500")
    static let working = Color(hex: "34C759")
    static let cooldown = Color(hex: "5AC8FA")
    static let dropSet = Color(hex: "9B59B6")
    static let failure = Color(hex: "FF3B30")

    // Chart Colors
    static let chartPositive = Color(hex: "00CC66")
    static let chartNegative = Color(hex: "FF3B30")
    static let chartGrid = Color(hex: "161D26")

    // Muscle Group Colors (for balance chart)
    static let muscleGroupColors: [String: Color] = [
        "chest": Color(hex: "FF6B6B"),
        "back": Color(hex: "4ECDC4"),
        "shoulders": Color(hex: "45B7D1"),
        "biceps": Color(hex: "96CEB4"),
        "triceps": Color(hex: "FFEAA7"),
        "quads": Color(hex: "DDA0DD"),
        "hamstrings": Color(hex: "98D8C8"),
        "glutes": Color(hex: "F7DC6F"),
        "calves": Color(hex: "BB8FCE"),
        "abs": Color(hex: "85C1E9"),
        "forearms": Color(hex: "F0B27A"),
    ]
}

enum RQSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40

    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 4
    static let cardSpacing: CGFloat = 10
    static let screenHorizontal: CGFloat = 16
}

enum RQRadius {
    static let small: CGFloat = 2
    static let medium: CGFloat = 4
    static let large: CGFloat = 6
    static let extraLarge: CGFloat = 12
}
