import Foundation

/// The parenthetical after an exercise name on program and template rows:
/// the rep target the engine will actually run, and how the sets are laid out.
func schemeSummary(mode: TrainingMode, scheme: SetScheme, rule: ProgressionRule = .autoregulated, repCap: Int?) -> String {
    if rule == .wave531 {
        return "(5/3/1 wave)"
    }
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
