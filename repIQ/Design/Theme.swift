import SwiftUI

enum RQColors {
    // Primary - Electric Blue accent
    static let accent = Color(hex: "00AAFF")
    static let accentLight = Color(hex: "33BBFF")
    static let accentDark = Color(hex: "0088CC")

    // Backgrounds - the "Tide" ramp. Neutrals are pulled toward the accent's
    // hue as flat tints, never gradients, so #00AAFF reads as part of the page
    // rather than floating above it. The four values sit within a narrow
    // lightness band on purpose: depth comes from small consistent steps plus
    // a shadow, and wide jumps between surfaces look cheap.
    static let background = Color(hex: "080C11")
    static let surfacePrimary = Color(hex: "0E161E")
    static let surfaceSecondary = Color(hex: "12202C")
    static let surfaceTertiary = Color(hex: "1A2A38")

    // Structure - the 1px rules the flow layout is built on. Distinct from the
    // text ramp: a border is not disabled text and should not borrow its value.
    static let hairline = Color(hex: "16232F")

    /// Inset top edge on a raised sheet — the highlight a real surface catches
    /// along its upper lip. Tinted rather than pure white so it belongs to the
    /// same ramp as everything else.
    static let edgeHighlight = Color(hex: "96CDFF").opacity(0.07)

    // Text - carries the same hue bias as the surfaces
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "8FA5BA")
    static let textTertiary = Color(hex: "5E7488")

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

    // MARK: - Sheet geometry (Tide)
    //
    // The rounded surface system the Progress tab is built on. Kept separate
    // from the sharp scale above so screens can migrate one at a time rather
    // than every corner in the app changing at once.
    //
    // `sheetInner` is deliberately `sheet - pad`: a nested element inside a
    // padded card needs a smaller radius or the two curves fight, which is the
    // most common tell of a layout nobody measured.

    static let sheet: CGFloat = 18
    static let sheetInner: CGFloat = 11
    static let control: CGFloat = 9
    /// Any value beyond half the height gives a capsule; this is the intent.
    static let pill: CGFloat = 999
}

// MARK: - Sheet surface

/// The raised plane the Tide layout is built from.
///
/// Two shadows rather than one: a tight contact shadow that anchors the card
/// to the page, and a wide soft one that gives it height. A single blurred
/// shadow reads as a stock component; the pair reads as an object resting on
/// a surface. The inset top edge is the highlight along the card's upper lip.
struct RQSheet: ViewModifier {
    var fill: Color = RQColors.surfacePrimary
    var radius: CGFloat = RQRadius.sheet
    /// Raised sheets sit above the page's own cards and carry a deeper shadow.
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .top) {
                RQColors.edgeHighlight
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .shadow(color: .black.opacity(elevated ? 0.55 : 0.45), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(elevated ? 0.45 : 0.32), radius: elevated ? 30 : 26, x: 0, y: elevated ? 12 : 10)
    }
}

extension View {
    /// Applies the Tide sheet surface. Pass `elevated` for a card that sits
    /// above the page's other cards, such as the tab's headline or its
    /// single call to action.
    func rqSheet(
        fill: Color = RQColors.surfacePrimary,
        radius: CGFloat = RQRadius.sheet,
        elevated: Bool = false
    ) -> some View {
        modifier(RQSheet(fill: fill, radius: radius, elevated: elevated))
    }
}
