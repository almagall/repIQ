import SwiftUI

/// Renders per-muscle effective-reps (Beardsley framework): out of every
/// rep performed in the last 30 days, what fraction was within ~5 RIR of
/// failure. Helps users distinguish stimulating volume from junk volume.
struct EffectiveRepsCard: View {
    let summaries: [EffectiveRepsSummary]

    private var sorted: [EffectiveRepsSummary] {
        summaries
            .filter { $0.totalReps > 0 }
            .sorted { $0.effectiveRatio > $1.effectiveRatio }
    }

    private var totalEffective: Int { sorted.reduce(0) { $0 + $1.effectiveReps } }
    private var totalReps: Int { sorted.reduce(0) { $0 + $1.totalReps } }
    private var aggregateRatio: Double {
        guard totalReps > 0 else { return 0 }
        return Double(totalEffective) / Double(totalReps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            RQSectionHeader(title: "EFFECTIVE REPS · LAST 30 DAYS")

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    summaryHeader

                    if !sorted.isEmpty {
                        Divider().background(RQColors.surfaceTertiary)
                        ForEach(sorted.prefix(5)) { entry in
                            entryRow(entry)
                        }
                    }

                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundColor(RQColors.textTertiary)
                        Text("Effective reps = sets within ~5 reps of failure, where most muscle-fibre stimulus comes from.")
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: RQSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalEffective)")
                    .font(RQTypography.title3)
                    .foregroundColor(RQColors.textPrimary)
                Text("EFFECTIVE OF \(totalReps) REPS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(RQColors.textTertiary)
            }
            Spacer()
            Text(String(format: "%.0f%%", aggregateRatio * 100))
                .font(RQTypography.numbersSmall)
                .foregroundColor(ratioColor(aggregateRatio))
        }
    }

    private func entryRow(_ entry: EffectiveRepsSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(entry.color)
                Spacer()
                Text("\(entry.effectiveReps) / \(entry.totalReps)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(RQColors.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(RQColors.surfaceTertiary)
                        .frame(height: 4)
                    Rectangle()
                        .fill(ratioColor(entry.effectiveRatio))
                        .frame(
                            width: geo.size.width * CGFloat(min(entry.effectiveRatio, 1.0)),
                            height: 4
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .frame(height: 4)
        }
        .padding(.vertical, 3)
    }

    private func ratioColor(_ ratio: Double) -> Color {
        if ratio >= 0.5 { return RQColors.success }
        if ratio >= 0.3 { return RQColors.info }
        if ratio >= 0.15 { return RQColors.warning }
        return RQColors.error
    }
}
