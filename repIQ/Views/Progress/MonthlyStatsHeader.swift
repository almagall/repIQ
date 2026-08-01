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
            RQSectionHeader(title: "THIS MONTH · \(monthLabel)")

            RQCard(bordered: false) {
                RQStatRow(items: [
                    .init(
                        "WORKOUTS",
                        "\(stats?.workouts ?? 0)",
                        delta: intDelta(current: stats?.workouts, previous: stats?.previousMonth?.workouts)
                    ),
                    .init(
                        "PRS",
                        "\(stats?.prCount ?? 0)",
                        delta: intDelta(current: stats?.prCount, previous: stats?.previousMonth?.prCount)
                    ),
                    .init(
                        "SETS",
                        "\(stats?.totalSets ?? 0)",
                        delta: intDelta(current: stats?.totalSets, previous: stats?.previousMonth?.totalSets)
                    ),
                    .init("AVG RPE", rpeDisplay, delta: rpeDelta()),
                ])
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

}
