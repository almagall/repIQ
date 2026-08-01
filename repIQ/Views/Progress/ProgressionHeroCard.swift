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
    /// How the figure reads. Home leads with the ring because the fraction is
    /// the whole screen's answer; Progress sets it inline because the tab
    /// continues into per-lift detail underneath.
    enum Style {
        case inline
        case ring
    }

    let verdict: ProgressionVerdict
    /// Forward-looking coaching line — the top-priority insight. Optional
    /// because a brand-new account has nothing worth saying yet.
    let coaching: InsightCard?
    var style: Style = .inline

    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusLabel

            if verdict.isBaseline {
                baselineFigure
            } else {
                switch style {
                case .inline: verdictFigure
                case .ring: ringFigure
                }
                decisionRails
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

    // MARK: - Ring

    /// The arc is literally movingUp / total — the geometry is the data, not a
    /// weighted index. That distinction is why this can be a ring at all.
    private var ringFigure: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(RQColors.surfaceTertiary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: hasAppeared ? verdict.progressingShare : 0)
                    .stroke(
                        verdict.trend.color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.9), value: hasAppeared)

                VStack(spacing: RQSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(verdict.movingUp)")
                            .font(RQTypography.title1)
                            .foregroundColor(RQColors.textPrimary)
                        Text("/\(verdict.total)")
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.4), value: verdict.movingUp)

                    Text("MOVING UP")
                        .rqLabel()
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .frame(width: 132, height: 132)
            Spacer()
        }
        .padding(.top, RQSpacing.md)
    }

    // MARK: - Rails

    /// The four decision counts the verdict is built from. They sum to `total`,
    /// so the headline can never drift from its own explanation.
    private var decisionRails: some View {
        VStack(spacing: 0) {
            rail("Weight increases", verdict.addedWeight, RQColors.stateAdvancing)
            rail("Rep increases", verdict.addedReps, RQColors.stateAdvancing)
            rail("Holding", verdict.holding, RQColors.stateHolding)
            rail("Backing off", verdict.deloading, RQColors.stateBacking)
        }
        .padding(.top, RQSpacing.md)
    }

    @ViewBuilder
    private func rail(_ name: String, _ count: Int, _ tint: Color) -> some View {
        if count > 0 {
            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                HStack {
                    Text(name)
                        .font(RQTypography.callout)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text("\(count)")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(tint)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(RQColors.surfaceTertiary)
                        Rectangle()
                            .fill(tint)
                            .frame(width: geo.size.width * share(count))
                    }
                }
                .frame(height: 2)
            }
            .padding(.vertical, RQSpacing.xs)
        }
    }

    private func share(_ count: Int) -> CGFloat {
        guard verdict.total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(verdict.total)
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
                    .font(RQTypography.hero)
                    .foregroundColor(RQColors.textPrimary)
                Text("/\(verdict.total)")
                    .font(RQTypography.title1)
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
