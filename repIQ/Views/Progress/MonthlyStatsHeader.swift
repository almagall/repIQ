import SwiftUI

/// 4-metric snapshot of the user's current month, shown at the top of the Progress tab.
/// Answers: did I train consistently? Did I hit breakthroughs? Did I put in the work?
/// Did I push hard?
struct MonthlyStatsHeader: View {
    let stats: MonthlyStats?

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack {
                Text("THIS MONTH · \(monthLabel)")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
            }

            RQCard {
                HStack(spacing: 0) {
                    statTile(
                        value: "\(stats?.workouts ?? 0)",
                        label: "WORKOUTS",
                        delta: intDelta(current: stats?.workouts, previous: stats?.previousMonth?.workouts)
                    )
                    Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                    statTile(
                        value: "\(stats?.prCount ?? 0)",
                        label: "PRS",
                        delta: intDelta(current: stats?.prCount, previous: stats?.previousMonth?.prCount)
                    )
                    Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                    statTile(
                        value: "\(stats?.totalSets ?? 0)",
                        label: "SETS",
                        delta: intDelta(current: stats?.totalSets, previous: stats?.previousMonth?.totalSets)
                    )
                    Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                    statTile(
                        value: rpeDisplay,
                        label: "AVG RPE",
                        delta: rpeDelta()
                    )
                }
            }
        }
    }

    private var rpeDisplay: String {
        guard let rpe = stats?.avgRPE else { return "—" }
        return String(format: "%.1f", rpe)
    }

    /// Returns a delta tuple (sign, label) for an integer metric, or nil if no comparison.
    private func intDelta(current: Int?, previous: Int?) -> (sign: Int, label: String)? {
        guard let current, let previous, previous > 0 || current > 0 else { return nil }
        let diff = current - previous
        guard diff != 0 else { return nil }
        return (sign: diff > 0 ? 1 : -1, label: "\(abs(diff))")
    }

    /// RPE delta is rendered with one decimal place since the values are decimals.
    private func rpeDelta() -> (sign: Int, label: String)? {
        guard let cur = stats?.avgRPE, let prev = stats?.previousMonth?.avgRPE else { return nil }
        let diff = cur - prev
        guard abs(diff) >= 0.1 else { return nil }
        return (sign: diff > 0 ? 1 : -1, label: String(format: "%.1f", abs(diff)))
    }

    private func statTile(value: String, label: String, delta: (sign: Int, label: String)?) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(value)
                .font(RQTypography.title3)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
            if let delta {
                HStack(spacing: 1) {
                    Image(systemName: delta.sign > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7, weight: .bold))
                    Text(delta.label)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(delta.sign > 0 ? RQColors.success : RQColors.warning)
            } else {
                // Placeholder to keep tile heights consistent
                Text(" ")
                    .font(.system(size: 9))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
