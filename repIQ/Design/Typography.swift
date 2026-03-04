import SwiftUI

enum RQTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 22, weight: .semibold)
    static let title3 = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)

    // Monospaced for numbers (weight, reps, RPE)
    static let numbers = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let numbersSmall = Font.system(size: 17, weight: .semibold, design: .monospaced)

    // Big target display
    static let targetWeight = Font.system(size: 48, weight: .heavy, design: .rounded)
}
