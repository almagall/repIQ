import SwiftUI

enum RQColors {
    // Primary - Electric Blue accent
    static let accent = Color(hex: "00AAFF")
    static let accentLight = Color(hex: "33BBFF")
    static let accentDark = Color(hex: "0088CC")

    // Backgrounds - pure black, high contrast
    static let background = Color(hex: "000000")
    static let surfacePrimary = Color(hex: "0A0A0A")
    static let surfaceSecondary = Color(hex: "141414")
    static let surfaceTertiary = Color(hex: "1C1C1C")

    // Text - pure white, sharp contrast
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "999999")
    static let textTertiary = Color(hex: "555555")

    // Semantic
    static let success = Color(hex: "00CC66")
    static let warning = Color(hex: "FF9500")
    static let error = Color(hex: "FF3B30")
    static let info = Color(hex: "5AC8FA")

    // Training Modes
    static let hypertrophy = Color(hex: "9B59B6")
    static let strength = Color(hex: "FF6B35")

    // Set Types
    static let warmup = Color(hex: "FF9500")
    static let working = Color(hex: "34C759")
    static let cooldown = Color(hex: "5AC8FA")
    static let dropSet = Color(hex: "9B59B6")
    static let failure = Color(hex: "FF3B30")
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
