import SwiftUI

/// The Progress tab's headline: how many lifts get a harder target next
/// session, and what the engine decided for the rest.
///
/// Reports progression rather than adherence on purpose. Adherence is the whole
/// section underneath this card, and a hero that summarised its own rows would
/// be a subtotal wearing a headline's clothes. These are two different
/// measurements — a soft prescription produces high adherence and no progress —
/// so the tab shows the outcome here and the mechanism below.
struct TargetsHeroCard: View {
    let verdict: ProgressionVerdict
    let presentation: TargetsOverviewViewModel.Presentation
    let coaching: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            header

            switch presentation {
            case .firstRun:
                firstRunBody
            case let .baseline(ready, total):
                baselineBody(ready: ready, total: total)
            case .active:
                activeBody
            case let .paused(daysSince, lastTrained):
                pausedBody(daysSince: daysSince, lastTrained: lastTrained)
            }

            if let coaching {
                Text(coaching)
                    .font(RQTypography.sheetBody)
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet(fill: RQColors.surfaceSecondary, elevated: true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(headerLabel)
                .rqSheetLabel()
                .foregroundColor(RQColors.textTertiary)
            Spacer()
            statusChip
        }
    }

    private var headerLabel: String {
        switch presentation {
        case .paused: return "Last trained"
        default: return "Targets going up"
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        switch presentation {
        case .active:
            chip(verdict.headline.capitalized, color: verdict.trend.color)
        case .baseline:
            chip("Building", color: RQColors.textSecondary)
        case .paused:
            chip("Paused", color: RQColors.stateHolding)
        case .firstRun:
            EmptyView()
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(RQTypography.sheetLabel)
            .tracking(RQTypography.sheetLabelTracking)
            .textCase(.uppercase)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.xs + 1)
            .background(color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: RQRadius.control - 2, style: .continuous))
    }

    // MARK: - Bodies

    /// No giant figure here — a dash set at display size and heavy weight reads
    /// as a white bar, not as an absent number. An empty state should say what
    /// happens next instead of drawing a placeholder for data that isn't there.
    private var firstRunBody: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("Targets start after your third session")
                .font(RQTypography.figureL)
                .tracking(RQTypography.figureTracking)
                .foregroundColor(RQColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("repIQ watches how each lift goes, then tells you exactly what to lift next time. This is where you'll see how often you hit it.")
                .font(RQTypography.sheetBody)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeBody: some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            figure(
                value: "\(verdict.movingUp)",
                suffix: "/\(verdict.total)",
                caption: "next session"
            )
            decisionBar
            decisionKeys
        }
    }

    private func baselineBody(ready: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            figure(
                value: "\(ready)",
                suffix: total > 0 ? "/\(total)" : nil,
                caption: "lifts ready"
            )
            Text(baselineExplanation(ready: ready, total: total))
                .font(RQTypography.sheetBody)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func baselineExplanation(ready: Int, total: Int) -> String {
        let waiting = max(total - ready, 0)
        guard waiting > 0 else {
            return "Keep logging — targets appear once a lift has a few sessions behind it."
        }
        return waiting == 1
            ? "One more lift needs another session before repIQ can set its target."
            : "\(waiting) lifts need another session each before repIQ can set their targets."
    }

    private func pausedBody(daysSince: Int, lastTrained: Date) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            figure(
                value: lastTrained.formatted(.dateTime.month(.abbreviated).day()),
                caption: "\(daysSince) days ago"
            )
            Text("Your targets are held where you left them. repIQ will ease the first session back rather than picking up mid-block.")
                .font(RQTypography.sheetBody)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Figure

    private func figure(value: String, suffix: String? = nil, caption: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: RQSpacing.md) {
            Text(value)
                .rqFigure(RQTypography.figureXL)
                .foregroundColor(RQColors.textPrimary)
            if let suffix {
                Text(suffix)
                    .rqFigure(RQTypography.figureM)
                    .foregroundColor(RQColors.textTertiary)
            }
            Text(caption)
                .font(RQTypography.sheetCaption)
                .foregroundColor(RQColors.textSecondary)
                .padding(.bottom, RQSpacing.xs)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Decision bar
    //
    // One bar rather than four rails: the four decisions are parts of a whole
    // that must sum to the tracked-lift count, and a stacked bar is the only
    // encoding where that's structurally true rather than merely accurate.

    private var decisionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(segments, id: \.label) { segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segment.color)
                        .frame(width: max(width(for: segment, in: geo.size.width), 3))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
    }

    private var decisionKeys: some View {
        // Wraps rather than truncating — on a narrow phone four keys need two
        // lines, and a clipped legend is worse than a taller card.
        FlowLayout(spacing: RQSpacing.lg, lineSpacing: RQSpacing.sm) {
            ForEach(segments, id: \.label) { segment in
                HStack(spacing: RQSpacing.sm) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(segment.color)
                        .frame(width: 7, height: 7)
                    Text("\(segment.count) \(segment.label)")
                        .font(RQTypography.sheetCaption)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private struct Segment {
        let count: Int
        let label: String
        let color: Color
    }

    /// Zero-count decisions are dropped so a sparse account doesn't render a
    /// legend of mostly nothing.
    private var segments: [Segment] {
        [
            Segment(count: verdict.addedWeight, label: "more weight", color: RQColors.stateAdvancing),
            Segment(count: verdict.addedReps, label: "more reps", color: RQColors.stateAdvancing.opacity(0.55)),
            Segment(count: verdict.holding, label: "same target", color: RQColors.surfaceTertiary),
            Segment(count: verdict.deloading, label: "eased back", color: RQColors.surfaceTertiary.opacity(0.6)),
        ].filter { $0.count > 0 }
    }

    private func width(for segment: Segment, in total: CGFloat) -> CGFloat {
        guard verdict.total > 0 else { return 0 }
        let gaps = CGFloat(max(segments.count - 1, 0)) * 3
        return (total - gaps) * CGFloat(segment.count) / CGFloat(verdict.total)
    }
}
