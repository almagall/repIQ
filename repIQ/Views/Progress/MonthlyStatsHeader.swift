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
                    statTile(value: "\(stats?.workouts ?? 0)", label: "WORKOUTS")
                    Divider().frame(height: 32).background(RQColors.surfaceTertiary)
                    statTile(value: "\(stats?.prCount ?? 0)", label: "PRS")
                    Divider().frame(height: 32).background(RQColors.surfaceTertiary)
                    statTile(value: "\(stats?.totalSets ?? 0)", label: "SETS")
                    Divider().frame(height: 32).background(RQColors.surfaceTertiary)
                    statTile(value: rpeDisplay, label: "AVG RPE")
                }
            }
        }
    }

    private var rpeDisplay: String {
        guard let rpe = stats?.avgRPE else { return "—" }
        return String(format: "%.1f", rpe)
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
}
