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

    // Technical label - uppercase section headers
    static let label = Font.system(size: 10, weight: .semibold, design: .monospaced)
}
