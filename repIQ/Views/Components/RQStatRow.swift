import SwiftUI

/// A row of 2–4 figures split by vertical hairlines: value over a tracked
/// uppercase label, optionally with a delta underneath.
///
/// This layout had been re-implemented as a private `statTile` in half a dozen
/// views, each with its own spacing and value font. It reads as data rather
/// than decoration precisely because the label is small and the rule is thin,
/// so the details are worth having in one place.
struct RQStatRow: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        /// Change against the comparable previous period. Sign drives both the
        /// arrow and the colour; the label is already absolute.
        var delta: (sign: Int, label: String)?

        init(_ label: String, _ value: String, delta: (sign: Int, label: String)? = nil) {
            self.label = label
            self.value = value
            self.delta = delta
        }
    }

    enum Prominence {
        /// Section-level totals — lifetime, this month.
        case section
        /// Inline within a card that has its own headline above it.
        case inline

        var valueFont: Font {
            switch self {
            case .section: return RQTypography.title3
            case .inline: return RQTypography.numbersSmall
            }
        }
    }

    let items: [Item]
    var prominence: Prominence = .section

    private var reservesDeltaLine: Bool {
        items.contains { $0.delta != nil }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(RQColors.hairline)
                        .frame(width: 1, height: 36)
                }
                tile(item)
            }
        }
    }

    private func tile(_ item: Item) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(item.value)
                .font(prominence.valueFont)
                .foregroundColor(RQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(item.label)
                .rqLabel()
                .foregroundColor(RQColors.textTertiary)
                .lineLimit(1)

            if let delta = item.delta {
                HStack(spacing: 1) {
                    Image(systemName: delta.sign > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7, weight: .bold))
                    Text(delta.label)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(delta.sign > 0 ? RQColors.stateAdvancing : RQColors.stateHolding)
            } else if reservesDeltaLine {
                // Keeps labels on a common baseline when only some tiles in the
                // row have a delta to show.
                Text(" ").font(.system(size: 10))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
