import SwiftUI

enum RQColors {
    // Primary - Gold/Amber accent
    static let accent = Color(hex: "D4A847")
    static let accentLight = Color(hex: "E8C96A")
    static let accentDark = Color(hex: "B8912E")

    // Backgrounds
    static let background = Color(hex: "0A0A0C")
    static let surfacePrimary = Color(hex: "141418")
    static let surfaceSecondary = Color(hex: "1E1E24")
    static let surfaceTertiary = Color(hex: "28282F")

    // Text
    static let textPrimary = Color(hex: "F5F5F7")
    static let textSecondary = Color(hex: "8E8E93")
    static let textTertiary = Color(hex: "5A5A5E")

    // Semantic
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let error = Color(hex: "FF3B30")
    static let info = Color(hex: "5AC8FA")

    // Training Modes
    static let hypertrophy = Color(hex: "AF52DE")
    static let strength = Color(hex: "FF6B35")

    // Set Types
    static let warmup = Color(hex: "5AC8FA")
    static let working = accent
    static let cooldown = Color(hex: "8E8E93")
}

enum RQSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let screenHorizontal: CGFloat = 20
}

enum RQRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
}
