import Foundation

/// Translates a raw weight in pounds into a "X.Y times a Toyota Corolla"
/// style comparison. Spotify Wrapped won the genre with "minutes listened" —
/// these are the lifting equivalents that turn forgettable numbers into
/// screenshot-bait.
///
/// The table is intentionally sparse and ordered ascending; `bestFit(for:)`
/// picks the largest unit whose weight is ≤ the input so the multiplier
/// always reads as a positive integer-or-decimal greater than one.
struct MemorableUnit {
    let label: String        // "a Toyota Corolla"
    let weightLbs: Double

    static let table: [MemorableUnit] = [
        .init(label: "a refrigerator",     weightLbs: 200),
        .init(label: "a grand piano",      weightLbs: 1_000),
        .init(label: "a small car engine", weightLbs: 1_500),
        .init(label: "a Toyota Corolla",   weightLbs: 2_955),
        .init(label: "a Ford F-150",       weightLbs: 4_700),
        .init(label: "an African elephant", weightLbs: 13_000),
        .init(label: "a school bus",       weightLbs: 30_000),
        .init(label: "a humpback whale",   weightLbs: 80_000),
        .init(label: "a blue whale",       weightLbs: 300_000),
        .init(label: "the Eiffel Tower",   weightLbs: 22_046_000)
    ]

    /// Returns the largest unit ≤ `pounds` along with the multiplier.
    /// Returns `nil` for inputs below the smallest unit (200 lbs).
    static func bestFit(for pounds: Double) -> (unit: MemorableUnit, multiplier: Double)? {
        guard pounds >= table.first!.weightLbs else { return nil }
        let unit = table.last(where: { $0.weightLbs <= pounds }) ?? table.first!
        return (unit, pounds / unit.weightLbs)
    }

    /// "1.4× a Toyota Corolla" or "12× a refrigerator" — picks integer or
    /// one-decimal formatting based on multiplier size.
    static func phrase(for pounds: Double) -> String? {
        guard let fit = bestFit(for: pounds) else { return nil }
        let multiplier = fit.multiplier
        let formatted: String
        if multiplier >= 10 {
            formatted = String(format: "%.0f", multiplier)
        } else {
            formatted = String(format: "%.1f", multiplier)
        }
        return "\(formatted)× \(fit.unit.label)"
    }
}
