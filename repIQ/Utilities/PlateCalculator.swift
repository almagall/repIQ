import Foundation

struct PlateCalculator {
    struct PlateResult {
        let plates: [Double] // plates per side, sorted largest to smallest
        let barWeight: Double
        let totalWeight: Double
        let isExact: Bool // whether plates perfectly match the target

        var perSideWeight: Double {
            (totalWeight - barWeight) / 2.0
        }
    }

    static let standardPlatesLbs: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Calculates plates per side for a given total weight.
    /// Returns nil if weight is at or below bar weight.
    static func calculate(
        totalWeight: Double,
        barWeight: Double = AppConstants.Defaults.barWeight
    ) -> PlateResult? {
        guard totalWeight > barWeight else { return nil }

        let perSide = (totalWeight - barWeight) / 2.0
        var remaining = perSide
        var plates: [Double] = []

        for plate in standardPlatesLbs {
            while remaining >= plate - 0.01 { // small epsilon for floating point
                plates.append(plate)
                remaining -= plate
            }
        }

        return PlateResult(
            plates: plates,
            barWeight: barWeight,
            totalWeight: totalWeight,
            isExact: remaining < 0.01
        )
    }
}
