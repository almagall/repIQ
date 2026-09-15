import Foundation

/// A per-lift training max: the number percentage-based rules prescribe from.
/// 5/3/1 sets it at 90% of a true or estimated 1RM so every prescribed set is
/// submaximal. Rows are append-only; the latest is the current TM.
struct TrainingMax: Codable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case manual
        case estimated
        case bump
        case hold
        case reset
        case recalibrated

        /// Cycle-end verdicts that departed from the book's "+5/+10 every
        /// cycle" rule. The next session offers the book's alternative.
        var deviatesFromBook: Bool {
            self == .hold || self == .recalibrated
        }
    }

    let id: UUID
    let userId: UUID
    let exerciseId: UUID
    let value: Double
    let source: Source
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case value
        case source
        case createdAt = "created_at"
    }
}
