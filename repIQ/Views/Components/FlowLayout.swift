import SwiftUI

/// A wrapping `HStack` — children flow onto as many lines as they need.
///
/// SwiftUI has no built-in equivalent, and an `HStack` silently clips its last
/// child rather than wrapping, which is how legends lose a key on smaller
/// phones. Used by the muscle-balance chips and the Progress hero's decision
/// keys.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    /// Vertical gap between wrapped lines. Defaults to `spacing` so a single
    /// value still reads as "gap".
    var lineSpacing: CGFloat?

    private var rowGap: CGFloat { lineSpacing ?? spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(for: subviews, in: width)
        let height = rows.reduce(0) { $0 + $1.height }
            + rowGap * CGFloat(max(rows.count - 1, 0))
        let resolvedWidth = width.isFinite ? width : (rows.map(\.width).max() ?? 0)
        return CGSize(width: resolvedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowGap
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if projected > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = projected
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
