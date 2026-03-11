import Foundation

/// Volume landmark reference data based on Renaissance Periodization guidelines (Dr. Mike Israetel).
/// MEV = Minimum Effective Volume (sets/week to maintain/slowly progress)
/// MAV = Maximum Adaptive Volume (sweet spot range for best gains)
/// MRV = Maximum Recoverable Volume (upper limit before recovery is compromised)
///
/// Values represent weekly direct working sets for intermediate trainees.
/// Beginners need fewer sets; advanced trainees may tolerate more.
enum VolumeLandmarkReference {

    struct Landmark {
        let mev: Int
        let mavLower: Int
        let mavUpper: Int
        let mrv: Int

        var mavRange: ClosedRange<Int> { mavLower...mavUpper }
    }

    /// Reference landmarks per muscle group (sets per week for intermediates).
    static let landmarks: [String: Landmark] = [
        "chest":      Landmark(mev: 8,  mavLower: 12, mavUpper: 20, mrv: 22),
        "back":       Landmark(mev: 8,  mavLower: 12, mavUpper: 20, mrv: 25),
        "shoulders":  Landmark(mev: 6,  mavLower: 10, mavUpper: 16, mrv: 20),
        "quads":      Landmark(mev: 6,  mavLower: 10, mavUpper: 18, mrv: 20),
        "hamstrings": Landmark(mev: 4,  mavLower: 8,  mavUpper: 14, mrv: 16),
        "glutes":     Landmark(mev: 4,  mavLower: 8,  mavUpper: 16, mrv: 20),
        "biceps":     Landmark(mev: 4,  mavLower: 8,  mavUpper: 14, mrv: 20),
        "triceps":    Landmark(mev: 4,  mavLower: 6,  mavUpper: 12, mrv: 18),
        "calves":     Landmark(mev: 6,  mavLower: 8,  mavUpper: 16, mrv: 20),
        "abs":        Landmark(mev: 0,  mavLower: 6,  mavUpper: 16, mrv: 20),
        "forearms":   Landmark(mev: 2,  mavLower: 4,  mavUpper: 10, mrv: 14),
    ]

    /// Returns the landmark for a given muscle group, or a sensible default.
    static func landmark(for muscleGroup: String) -> Landmark {
        landmarks[muscleGroup] ?? Landmark(mev: 6, mavLower: 10, mavUpper: 16, mrv: 20)
    }
}
