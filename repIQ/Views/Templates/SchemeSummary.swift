import Foundation

/// The "(3-5 reps, straight)" fragment on template and program exercise rows.
/// Honours the rep cap and names the scheme only where it applies.
func schemeSummary(mode: TrainingMode, scheme: SetScheme, repCap: Int?) -> String {
    let full = mode.repRange
    let top = max(min(repCap ?? full.upperBound, full.upperBound), full.lowerBound)
    let reps = top == full.lowerBound ? "\(top) reps" : "\(full.lowerBound)-\(top) reps"
    switch mode {
    case .hypertrophy:
        return "(\(reps))"
    case .strength:
        return "(\(reps), \(scheme.displayName.lowercased()))"
    }
}
