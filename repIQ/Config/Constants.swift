import Foundation

enum AppConstants {
    static let appName = "repIQ"

    enum Defaults {
        static let restTimerSeconds = 90
        static let weightUnit: WeightUnit = .lbs
        static let barWeight: Double = 45.0 // lbs
        static let barWeightKg: Double = 20.0
        static let smartRestTimerEnabled = true
    }

    /// Adjustments applied by the smart rest timer based on the just-completed
    /// set's RPE. The aim is small, perceptible nudges in the right direction —
    /// not big jumps that fight the user's chosen base duration.
    enum SmartRest {
        static let highRPEThreshold: Double = 8.5
        static let lowRPEThreshold: Double = 6.0
        static let highRPEBonusSeconds = 60   // hard set → more rest
        static let lowRPEReductionSeconds = -30 // easy set → shorter rest
        static let minSeconds = 30
        static let maxSeconds = 600
    }

    /// UserDefaults keys shared across the app. Centralized so settings UI and
    /// the workout view model stay in sync without typo risk.
    enum UserDefaultsKeys {
        static let smartRestTimerEnabled = "smartRestTimerEnabled"
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
        static let range: ClosedRange<Double> = 1.0...10.0
        static let step: Double = 0.5
    }
}
