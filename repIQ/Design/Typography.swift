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

    // MARK: - Tide
    //
    // Proportional, not monospaced. The sheet layout leans on weight and size
    // contrast rather than the technical voice the sharp screens use, so these
    // are deliberately a separate ramp — mixing the two on one screen is what
    // made earlier drafts feel assembled rather than designed.
    //
    // Big figures pair with `.monospacedDigit()` at the call site so digits
    // hold their column when data refreshes, and with `figureTracking`, since
    // large type set at default spacing always looks loose.

    static let figureXL = Font.system(size: 56, weight: .heavy)
    static let figureL = Font.system(size: 34, weight: .heavy)
    static let figureM = Font.system(size: 20, weight: .heavy)

    static let sheetTitle = Font.system(size: 16, weight: .heavy)
    static let sheetBody = Font.system(size: 13, weight: .medium)
    static let sheetCaption = Font.system(size: 11, weight: .medium)

    /// Small caps-style section header for the sheet layout.
    static let sheetLabel = Font.system(size: 10, weight: .bold)
    static let sheetLabelTracking: CGFloat = 1.1

    /// −0.04em at display sizes. Large numerals set solid read as gappy.
    static let figureTracking: CGFloat = -2
}

extension View {
    /// Uppercase technical label: the font and the tracking it depends on.
    /// SwiftUI's `Font` cannot carry tracking, so the pair has to travel as a
    /// modifier rather than a single token.
    func rqLabel() -> some View {
        font(RQTypography.label).tracking(RQTypography.labelTracking)
    }

    /// Sheet-layout section header. Uppercased at the call site so the string
    /// stays readable in code.
    func rqSheetLabel() -> some View {
        font(RQTypography.sheetLabel)
            .tracking(RQTypography.sheetLabelTracking)
            .textCase(.uppercase)
    }

    /// Display figure: tightened tracking plus tabular digits, which together
    /// are the difference between a number that looks set and one that looks
    /// typed.
    func rqFigure(_ font: Font) -> some View {
        self.font(font)
            .tracking(RQTypography.figureTracking)
            .monospacedDigit()
    }
}
