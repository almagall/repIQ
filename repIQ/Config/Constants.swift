import Foundation

enum AppConstants {
    static let appName = "repIQ"

    enum Defaults {
        static let restTimerSeconds = 90
        static let weightUnit: WeightUnit = .lbs
        static let barWeight: Double = 45.0 // lbs
        static let barWeightKg: Double = 20.0
    }

    enum WeightIncrements {
        static let barbellLbs: Double = 5.0
        static let barbellKg: Double = 2.5
        static let dumbbellLbs: Double = 5.0
        static let dumbbellKg: Double = 2.5
        static let cableLbs: Double = 5.0
        static let cableKg: Double = 2.5
    }

    enum Progression {
        static let stallThreshold = 3
        static let rpeDriftThreshold: Double = 1.0
        static let hypertrophyDeloadPercent = 0.10
        static let strengthDeloadPercent = 0.15
        static let volumeDeloadPercent = 0.50
        static let sessionsToAnalyze = 3
    }

    enum RPE {
        static let range: ClosedRange<Double> = 6.0...10.0
        static let step: Double = 0.5
    }
}
