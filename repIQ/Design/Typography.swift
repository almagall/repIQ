import SwiftUI

enum RQTypography {
    // Titles - monospaced for industrial/technical feel
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let title1 = Font.system(size: 26, weight: .bold, design: .monospaced)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let title3 = Font.system(size: 18, weight: .semibold, design: .monospaced)

    // Body - proportional for readability
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let callout = Font.system(size: 14, weight: .regular)
    static let subheadline = Font.system(size: 13, weight: .regular)
    static let footnote = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .medium)

    // Monospaced for numbers (weight, reps, RPE)
    static let numbers = Font.system(size: 22, weight: .bold, design: .monospaced)
    static let numbersSmall = Font.system(size: 15, weight: .semibold, design: .monospaced)

    // Big target display - monospaced for TE feel
    static let targetWeight = Font.system(size: 44, weight: .heavy, design: .monospaced)

    // The set prescription, read at rack distance mid-set. One per screen.
    static let poster = Font.system(size: 76, weight: .heavy, design: .monospaced)

    // The progression answer on Home and Progress. One per screen.
    static let hero = Font.system(size: 52, weight: .heavy, design: .monospaced)

    // Technical label - uppercase section headers. Pair with labelTracking;
    // prefer the rqLabel() modifier so the two never drift apart.
    static let label = Font.system(size: 10, weight: .semibold, design: .monospaced)

    /// 0.2em at 10pt. Uppercase monospace set solid reads as a rendering bug.
    static let labelTracking: CGFloat = 2
}

extension View {
    /// Uppercase technical label: the font and the tracking it depends on.
    /// SwiftUI's `Font` cannot carry tracking, so the pair has to travel as a
    /// modifier rather than a single token.
    func rqLabel() -> some View {
        font(RQTypography.label).tracking(RQTypography.labelTracking)
    }
}
