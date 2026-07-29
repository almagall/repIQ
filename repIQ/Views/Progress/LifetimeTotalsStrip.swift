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
                HStack(spacing: 0) {
                    statTile(value: "\(totalSessions)", label: "WORKOUTS")
                    Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                    statTile(value: formatVolume(totalVolume), label: "VOLUME")
                    Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                    statTile(value: "\(totalPRCount)", label: "PRS")
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(value)
                .font(RQTypography.title3)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
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
