import SwiftUI

/// "You vs past you" card. Sits under the Last Workout recap and compares
/// the user's current top lift to where they were ~3 months ago. Quietly
/// disappears when the user lacks the historical depth to make a meaningful
/// comparison.
struct PastMeCard: View {
    let snapshot: PastMeSnapshot

    private var relativePast: String {
        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: snapshot.pastDate, to: Date()).month ?? 0
        if months >= 12 {
            let years = months / 12
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        if months <= 1 { return "1 month ago" }
        return "\(months) months ago"
    }

    private var deltaLabel: String? {
        let delta = snapshot.delta
        guard abs(delta) >= 1 else { return nil }
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.0f", abs(delta))) lb"
    }

    private var narrative: String {
        let delta = snapshot.delta
        let exercise = snapshot.exerciseName
        if delta > 25 {
            return "Massive progress on \(exercise) — keep stacking weeks like this."
        }
        if delta > 10 {
            return "Solid gain on \(exercise) — your work is showing."
        }
        if delta > 0 {
            return "Small gain on \(exercise) — every pound counts."
        }
        if delta > -10 {
            return "Holding steady on \(exercise) — consider a small progression push."
        }
        return "\(exercise) has slipped — check recovery, frequency, or programming."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            RQSectionHeader(title: "VS PAST YOU")

            RQCard(bordered: false) {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.exerciseName)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                                .lineLimit(1)
                            Text(relativePast.uppercased())
                                .font(RQTypography.label)
                                .tracking(0.5)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Spacer()
                        if let deltaLabel {
                            HStack(spacing: 2) {
                                Image(systemName: snapshot.delta >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                Text(deltaLabel)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(snapshot.delta >= 0 ? RQColors.success : RQColors.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: RQRadius.small)
                                    .stroke(snapshot.delta >= 0 ? RQColors.success : RQColors.warning, lineWidth: 0.5)
                            )
                        }
                    }

                    Divider().background(RQColors.surfaceTertiary)

                    HStack(spacing: 0) {
                        snapshotTile(
                            value: "\(Int(snapshot.pastE1RM.rounded())) lb",
                            label: "THEN",
                            detail: "\(Int(snapshot.pastWeight)) × \(snapshot.pastReps)"
                        )
                        Divider().frame(height: 36).background(RQColors.surfaceTertiary)
                        snapshotTile(
                            value: "\(Int(snapshot.currentE1RM.rounded())) lb",
                            label: "NOW",
                            detail: nil
                        )
                    }

                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundColor(RQColors.accent)
                        Text(narrative)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func snapshotTile(value: String, label: String, detail: String?) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
