import SwiftUI

/// Three-tile "lifetime" strip showing the user's total workouts, total volume,
/// and total PR count across all time. Sits below the current-month stats to
/// give weight to the user's accumulated work.
struct LifetimeTotalsStrip: View {
    let totalSessions: Int
    let totalVolume: Double
    let totalPRCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            RQSectionHeader(title: "LIFETIME")

            RQCard(bordered: false) {
                RQStatRow(items: [
                    .init("WORKOUTS", "\(totalSessions)"),
                    .init("VOLUME", formatVolume(totalVolume)),
                    .init("PRS", "\(totalPRCount)"),
                ])
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        }
        if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }
}
