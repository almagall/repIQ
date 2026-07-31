import SwiftUI

/// The Progress tab's headline answer to "am I actually progressing?".
///
/// Reports how many regularly-trained exercises the progression engine moved up
/// at their last session. This is deliberately not an e1RM trend: e1RM is
/// meaningless for bodyweight work and unreliable in the 10–15 rep band the
/// hypertrophy path lives in, whereas every exercise gets a progression
/// decision regardless of equipment or rep range.
///
/// The card is the only bordered element on the tab, so it reads as the single
/// focal point in an otherwise borderless scroll.
struct ProgressionHeroCard: View {
    let verdict: ProgressionVerdict
    /// Forward-looking coaching line — the top-priority insight. Optional
    /// because a brand-new account has nothing worth saying yet.
    let coaching: InsightCard?

    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusLabel

            if verdict.isBaseline {
                baselineFigure
            } else {
                verdictFigure
                if !verdict.breakdown.isEmpty {
                    Text(verdict.breakdown)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                        .padding(.top, RQSpacing.md)
                }
            }

            if let coaching {
                coachingLine(coaching)
            }
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RQColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.extraLarge)
                .stroke(RQColors.accentDark, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RQRadius.extraLarge))
        .onAppear { hasAppeared = true }
    }

    // MARK: - Status

    private var statusLabel: some View {
        HStack(spacing: RQSpacing.xs) {
            Image(systemName: verdict.isBaseline ? "clock" : verdict.trend.icon)
                .font(.system(size: 11, weight: .bold))
            Text(verdict.isBaseline ? "BUILDING BASELINE" : verdict.headline)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
        }
        .foregroundColor(verdict.isBaseline ? RQColors.textSecondary : verdict.trend.color)
        .padding(.bottom, RQSpacing.md)
    }

    // MARK: - Figures

    private var verdictFigure: some View {
        HStack(alignment: .firstTextBaseline, spacing: RQSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(verdict.movingUp)")
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundColor(RQColors.textPrimary)
                Text("/\(verdict.total)")
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(RQColors.textTertiary)
            }
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.4), value: verdict.movingUp)

            Text("exercises\nmoving up")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize()
        }
    }

    private var baselineFigure: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: RQSpacing.md) {
                Text("\(verdict.buildingBaseline)")
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundColor(RQColors.textPrimary)
                Text("exercises\nlogged so far")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize()
            }
            Text("Log three sessions of an exercise and it starts counting toward your trend.")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Coaching

    private func coachingLine(_ insight: InsightCard) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            Text("NEXT UP")
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.accent)
            Text(insight.message)
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, RQSpacing.lg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RQColors.hairline)
                .frame(height: 0.5)
        }
    }
}
