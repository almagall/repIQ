import SwiftUI

struct PreviousSetsView: View {
    let previousSets: [[WorkoutSet]]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        if let lastSession = previousSets.first, !lastSession.isEmpty {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Button(action: onToggle) {
                    HStack(spacing: RQSpacing.sm) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)

                        Text("Previous")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        if !isExpanded {
                            // Compact summary
                            Text(compactSummary(lastSession))
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }

                        Spacer()
                    }
                }

                if isExpanded {
                    VStack(spacing: RQSpacing.xs) {
                        ForEach(lastSession) { set in
                            HStack(spacing: RQSpacing.md) {
                                Text("Set \(set.setNumber)")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                    .frame(width: 44, alignment: .leading)

                                Text(formatWeight(set.weight))
                                    .font(RQTypography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(RQColors.textSecondary)

                                Text("×")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)

                                Text("\(set.reps)")
                                    .font(RQTypography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(RQColors.textSecondary)

                                if let rpe = set.rpe {
                                    Text("@\(formatRPE(rpe))")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(.leading, RQSpacing.lg)
                    .padding(.vertical, RQSpacing.xs)
                    .background(RQColors.surfaceSecondary.opacity(0.5))
                    .cornerRadius(RQRadius.small)
                }
            }
        }
    }

    private func compactSummary(_ sets: [WorkoutSet]) -> String {
        let count = sets.count
        if let first = sets.first {
            return "\(count)×\(formatWeight(first.weight))×\(first.reps)"
        }
        return "\(count) sets"
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
